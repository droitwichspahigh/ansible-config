#!/bin/sh
#
# This script requires root as it uses the machine credentials
# to connect to AD.
#
# It also reads the database credentials from the Leantime config
# file.

# Configurables

base_dn="OU=Staff,ou=DSHS,dc=dshs,dc=local"
ldap_filter="(&(objectClass=user)(objectCategory=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
# ldap_uri="ldap://dshs.local"

# lean_env defaults to curdir/config/.env
# and reads the DB config from there
#lean_env=
#lean_db_host=
#lean_db_user=
#lean_db_password=
#lean_db_database=
#lean_db_port=

# No user serviceable parts here

: ${lean_env:=`dirname $0`/config/.env}
: ${ldap_uri:=ldap://$(hostname -d)}

# This was really unnecessary but at least we don't need to put
# plaintext passwords here

extract_from_conf() {
	local _variable _uvariable
	_variable=$1

	_uvariable=$(echo $_variable | tr a-z A-Z)

	< $lean_env sed -ne "s,^$_uvariable *= *['\"]*\([^'\" ]*\).*,\1,p"
}

for v in host user password database port; do
	val=$(extract_from_conf LEAN_DB_$v)
	eval "lean_db_$v=\"$val\""
done

set -euo pipefail

MACHINE_PRINCIPAL="$(hostname -s | tr 'a-z' 'A-Z')\$"
KRB5CCNAME=$(mktemp /tmp/krb5cc_leantime_sync_XXXXXXX)
export KRB5CCNAME

trap 'kdestroy -q' EXIT
kinit -k "$MACHINE_PRINCIPAL"

ldapsearch -Y GSSAPI -Q -LLL -o ldif-wrap=no -H "$ldap_uri" -b "$base_dn" \
		"$ldap_filter" mail userPrincipalName givenName sn title department telephoneNumber | awk '
function sql_esc(s) {
  gsub(/\r/, "", s)
  gsub(/\\/, "\\\\", s)
  gsub(/\047/, "\047\047", s)
  return s
}
BEGIN { RS=""; FS="\n" }
{
  mail=""; upn=""; given=""; sn=""; title=""; dept=""
  for (i=1; i<=NF; i++) {
    sub(/\r$/, "", $i)
    if ($i ~ /^mail: /) mail=substr($i, 7)
    else if ($i ~ /^userPrincipalName: /) upn=substr($i, 20)
    else if ($i ~ /^givenName: /) given=substr($i, 12)
    else if ($i ~ /^sn: /) sn=substr($i, 5)
    else if ($i ~ /^title: /) title=substr($i, 8)
    else if ($i ~ /^department: /) dept=substr($i, 13)
    else if ($i ~ /^telephoneNumber: /) phone=substr($i, 18)
  }
  login_id = (mail != "") ? mail : upn
  if (login_id != "") {
    printf "UPDATE zp_user SET firstname = IF(\047%s\047 != \047\047, \047%s\047, firstname), lastname = IF(\047%s\047 != \047\047, \047%s\047, lastname), jobTitle = \047%s\047, phone = \047%s\047, department = \047%s\047 WHERE LOWER(username) = \047%s\047;\n",
      sql_esc(given), sql_esc(given),
      sql_esc(sn), sql_esc(sn),
      sql_esc(title),
      sql_esc(phone),
      sql_esc(dept),
      tolower(sql_esc(login_id))
  }
}' | mysql -h "$lean_db_host" -u "$lean_db_user" -p"$lean_db_password" "$lean_db_database" 2>&1 | grep -v " Using a password"
