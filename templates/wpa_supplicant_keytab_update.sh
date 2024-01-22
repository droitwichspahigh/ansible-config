#!/bin/sh

conf=/etc/wpa_supplicant.conf
ssid="DSHS Main"
keytab=/etc/krb5.keytab

chmod 600 $conf || install -o root -g wheel -m 600 /dev/null $conf

oldkeytabcs=$(/sbin/sha256 -q /etc/krb5.keytab)
machine_password=$(/usr/local/sbin/adcli update --add-samba-data --domain=DSHS.LOCAL --samba-data-tool=/usr/local/bin/net --show-password | sed -ne 's,^computer-password = ,,p' | iconv -t utf16le | openssl md4 | cut -d ' ' -f 2)
newkeytabcs=$(/sbin/sha256 -q /etc/krb5.keytab)

# Has it been changed?
if [ "$oldkeytabcs" = "$newkeytabcs" ]; then
	exit 0
fi

#machine_password=$(/usr/local/bin/tdbdump -k SECRETS/MACHINE_PASSWORD/CSE2K /var/db/samba4/private/secrets.tdb | \
#	/usr/bin/awk '
#BEGIN {
#	RS="\\";
#}
#/[0-9A-F][0-9A-F]/ {
#	if ($0 == "00") {
#		next;
#	}
#	printf ("%c", 0 + ("0x"$0));
#}' | \
#	/usr/bin/iconv -f utf-8 -t utf-16le | \
#	/usr/bin/openssl md4 | cut -d ' ' -f 2)

# This seems to be the most reliable method!
machine_password=$(/usr/local/bin/tdbdump -k SECRETS/MACHINE_PASSWORD/CSE2K /var/db/samba4/private/secrets.tdb | sed 's,\\00$,,;s,\\5[Cc],\\,g' | iconv -f utf-8 -t utf-16le | openssl md4 | cut -d ' ' -f 2)

oldpw=$(/usr/bin/sed -ne 's/^[[:space:]]password=hash://p' $conf)

if [ -z "$machine_password" ]; then
	echo "Error generating machine password!"
	exit 1
fi

if [ "$oldpw" = "$machine_password" ]; then
	# Password hasn't changed, no problem
	exit 0
fi

hostname_caps=$(hostname -s | tr a-z A-Z)

# Check for network and remove it
if grep -q "^[[:space:]]*ssid=\"*$ssid\"*\$" $conf; then
	printf "%s\n%s\n%s\nwq\n" "/$ssid" "?^network" ".,/}/d" | ed $conf
fi

# Then add the block to wpa_supplicant
>> $conf cat << EOF
network={
	ssid="$ssid"
	identity="${hostname_caps}\$"
	password=hash:$machine_password
	key_mgmt=WPA-EAP
}
EOF

/bin/pkill -HUP wpa_supplicant
/usr/local/sbin/sv restart sssd smbd nmbd winbindd
