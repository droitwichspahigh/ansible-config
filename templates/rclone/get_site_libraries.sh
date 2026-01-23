#!/bin/sh

: ${confdir=$(dirname $(realpath $0))}

args=$(getopt ic: $*)
if [ $? -ne 0 ]; then
	echo "Usage: $0 -c confdir -i"
	echo "-i: Interactively deal with new sites"
	exit 2
fi

set -- $args
while :; do
	case "$1" in
	-i)
		iopt=true
		shift
		;;
	-c)
		confdir="$2"
		shift; shift;
		;;
	--)
		shift; break;
		;;
	esac
done

for dep in jq curl; do
	if ! type $dep > /dev/null; then
		printf %s "Need to install $dep"
	fi
done

if [ -f $confdir/secrets ]; then
	. $confdir/secrets
else
	printf %s 'Enter client ID >' 1>&2
	read client_id
	printf %s 'Enter client secret >' 1>&2
	read client_secret
	printf %s 'Enter tenant ID https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Overview >' 1>&2
	read tenant_id
	install -m 600 /dev/null $confdir/secrets
	for t in client_id client_secret tenant_id; do
		eval printf "'%s\n' \"$t=\$$t\" >> secrets"
	done
fi

cd "$confdir"

token=$(curl --silent --show-error -d grant_type=client_credentials \
	-d client_id=$client_id \
	-d client_secret=$client_secret \
	-d scope=https://graph.microsoft.com/.default \
	-d resource=https://graph.microsoft.com \
	https://login.microsoftonline.com/$tenant_id/oauth2/token \
	| jq -j .access_token)

nextLink="https://graph.microsoft.com/v1.0/sites/microsoft.graph.getAllSites?\$filter=not%20contains(name,'Section_')%20and%20not%20startswith(name,'Exp09')+and+not+startswith(name,'202')+and+isPersonalSite+eq+false+and+not+startswith(name,'Exp102')"

while [ -n "$iopt" -a "$nextLink" != null -a -n "$nextLink" ]; do
	result=$(curl --silent --show-error -X GET \
		-H "Authorization: Bearer $token" \
		-H "Content-Type: application/json" \
		$nextLink)
	nextLink=$(echo $result | jq '."@odata.nextLink"')
	nextLink=${nextLink%\"}
	nextLink=${nextLink#\"}
	echo $result | jq '.value[] | "\(.displayName)|\(.id)"'
done | sed 's,^",,;s,"$,,;s/|\([^,]*\),/|\1|/;s/|\([^,]*\),/|\1|/' | sort > sites_tmp

for f in accepted rejected; do
	[ -f sites_$f ] || touch sites_$f
done

comm -23 sites_tmp sites_accepted > sites_tmp2
comm -23 sites_tmp2 sites_rejected > sites_new

rm sites_tmp*

IFS='
'

for l in $(cat sites_new); do
	answer=dummy
	while [ "$answer" != 'n' -a "$answer" != 'y' -a "$answer" != 'stop' ]; do
		printf 'Include %s (y/n/stop)? ' "${l%%|*}"
		read answer
	done
	if [ "$answer" = 'y' ]; then
		printf '%s\n' $l >> sites_accepted.new
	elif [ "$answer" = 'n' ]; then
		printf '%s\n' $l >> sites_rejected.new
	else
		break
	fi
done

IFS=' 	
'

rm sites_new

for f in accepted rejected; do
	[ -f sites_$f.new ] || continue
	cat sites_$f.new sites_$f | sort -u > sites_$f.sorted
	mv sites_$f.sorted sites_$f
	rm sites_$f.new
done

# Woop, sites selected!  Let's go get the libraries now.

IFS='|'

combination=

while read name _junk id _junk2; do
	# Get the drives
	libs=$(curl --silent --show-error -X GET \
		-H "Authorization: Bearer $token" \
		-H "Content-Type: application/json" \
		https://graph.microsoft.com/v1.0/sites/$id/drives | jq '.value[] | "\(.name)|\(.id)"' | sed 's,^",,;s,"$,,')
	IFS='
'
	for l in $libs; do
		_lname=$(printf '%s - %s' "$name" "${l%\|*}" | tr -C -- '-A-Za-z0-9_ .+@\n' '_')
		_lid="${l#*\|}"
		combination=${combination}${combination:+|}$_lname
		printf "[%s]\n" "$_lname"
		echo "type = onedrive"
		printf "tenant = %s\n" "$tenant_id"
		printf "client_credentials=true\n"
		printf "client_id = %s\n" "$client_id"
		printf "client_secret = %s\n" "$client_secret"
		printf "drive_id = %s\n" "$_lid"
		printf "drive_type = documentLibrary\n\n"
	done
	IFS='|'
done < sites_accepted

printf '%s\n' '[all]'
printf '%s\n' 'type = combine'
printf '%s' 'upstreams = '

for c in $combination; do
	printf '"%s=%s:" ' $c $c
done

printf '\n'
