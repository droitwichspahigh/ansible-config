#!/bin/sh
#
# Backs up HP switches to a TFTP server running on the local machine
# Requires switch_backups.secrets, which contains a single line;
#
# switch_password="switch_manager_password"
#
# Also requires switch_backups.conf which contains a line for
# each switch to back up, firstly IP address then the hostname.
# Space or tab separated.
#
# Some sanitising is done of the hostname, but don't go mad with it.
#

. $(dirname $0)/switch_backups.secrets

MYIP=$(host "$(hostname)" | awk '/has address/ {print $4}')

if [ ! -d /switch_backups ] || [ ! -d /tftp ]; then
	echo Missing backup dir /switch_backups or /tftp
	exit 2
fi

while read ip fname; do
	# Skip comments
	case $ip in
		\#*)
			echo Skipping comment line
			continue
			;;
		*)
			;;
	esac
 
	fname_clean=$(echo "$fname" | tr -C 'A-Za-z0-9.\n-' '_')

	tmpfile=$(mktemp /tftp/switch_backup.XXXXXXXXX)
	destfile=$(basename $tmpfile)

	chown nobody:nobody "$tmpfile"

	expect <<EOF
set timeout 10
spawn telnet $ip
expect {
	"Press any key to continue" {
		send "\r"
		exp_continue
	}
	"Username: "	{
		send "manager\r"
		exp_continue
	}
	"Password: "	{
		send "$switch_password\r"
	}
	-re ".*# " {
		send "\r"
	}
}
expect -re ".*# " {
	send "copy running-config tftp $MYIP $destfile\r"
}
expect -re ".*# "		{ send "exit\r" }
expect -re ".*> "		{ send "exit\r" }
expect -re ".*Do you want to log out .*"		{ send "y\r" }
expect eof
EOF
	mv "$tmpfile" "/switch_backups/$fname_clean.txt"
	chown root:domain\ admins "/switch_backups/$fname_clean.txt"
	chmod g+r "/switch_backups/$fname_clean.txt"

done < $(dirname $0)/switch_backups.conf
