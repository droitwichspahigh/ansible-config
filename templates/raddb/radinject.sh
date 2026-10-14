#!/bin/sh

# Piped input from syslogd

read -r syslog_line

username="${syslog_line#*Account Name:}"

# Strip all leading spaces/tabs natively using case loops
while true; do
    case "$username" in
    " "*|'	'*)
	    username="${username#?}" # Strips space or tab from the front
	    ;;
    *)
	    break
	    ;;
    esac
done
username="${username%% *}"

ip="${syslog_line#*Client Address:}"
while true; do
    case "$ip" in
    " "*|'	'*)
	    ip="${ip#?}" # Strips space or tab from the front
	    ;;
    *)
	    break
	    ;;
    esac
done
ip="${ip%% *}"
ip="${ip#*::ffff:}"

# Don't process computer names
case "$username" in
*'$'|""|"-")
    exit 0
    ;;
esac

# Let's be selective about VLANs
case "$ip" in
# 6F
10.16.6[67].*)
    ;;
# North
10.16.6[89].*|10.16.7[01].*)
    ;;
# Central
10.16.7[2-5].*)
    ;;
# South
10.16.7[6-9].*)
    ;;
# Wifi
10.16.8[0-3].*)
    ;;
# BYOD
10.16.8[45].*)
    ;;
*)
    exit 0
    ;;
esac

RADSECRET=$(sed -ne 's, *secret *= *"\([^"]*\)",\1,p' /usr/local/etc/raddb/netsweeper_update.conf)
RADADDR=$(sed -ne 's, *ipaddr *= *\(.*\),\1,p' /usr/local/etc/raddb/netsweeper_update.conf)

if [ -z "$RADSECRET" -o -z "$RADADDR" ]; then
	echo 'Secret or address not in netsweeper_update.conf? Run with sh -x to troubleshoot'
	exit 2
fi

# Find SBB group, prioritise admin first as all admins are staff, then go smallest

class=Captive_Portal

case $(id -Gn "$username" 2>/dev/null) in
*'sbb admin web filtering'*)
	class=Admin_Web_Filtering
	;;
*'sbb pupil web filtering'*)
	class=Pupil_Web_Filtering
	;;
*'sbb ks5 web filtering'*)
	class=KS5_Web_Filtering
	;;
*'sbb staff web filtering'*)
	class=Staff_Web_Filtering
	;;
*)
	exit 0
	;;
esac

echo "User-Name = '$username', \
	Framed-IP-Address = $ip, \
	Acct-Status-Type = Start, \
	Class = 'SBB_$class@NSW-00115@OVLP3'" | \
    /usr/local/bin/radclient -x ${RADADDR}:1813 acct "$RADSECRET"
