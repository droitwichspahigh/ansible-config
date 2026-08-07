# cat create_console_user.sh 
#!/bin/sh

# User must be in this group
group_membership="domain admins"

username=$PAM_USER
username_l=$(printf %s $username | tr 'A-Z' 'a-z')

gid=$(getent group "$group_membership" | cut -d : -f 3)

all_gids=$(id -G $username)

userfile="/usr/local/etc/bareos/bareos-dir.d/user/$username_l.conf"

if [ "$all_gids" = "${all_gids#*$gid}" ]; then
        # Not a member of the group
        rm -f "$userfile"
        exit 2
fi

if [ -f "$userfile" ] && grep -q "$username" "$userfile"; then
        exit 0
fi

cat > "$userfile" << EOF
User {
  Name = "$username"
  Profile = webui-admin
}
EOF

/usr/local/sbin/bconsole -c /usr/local/etc/bareos/bconsole.conf > /tmp/bconsole-output 2>&1 << EOF
reload
EOF

exit $PAM_SUCCESS
