#!/bin/sh

# Check for the old version
grep -q 2e5582f3ee352dcd9da3bf816f34c24a /usr/local/etc/bareos/bareos-fd.d/director/bareos-dir.conf || exit 0

cd /usr/local/etc/bareos
dir_pwd=$(sed -ne s,^XXX_REPLACE_WITH_DIRECTOR_PASSWORD_XXX=,,p .rndpwd)
mon_pwd=$(sed -ne s,^XXX_REPLACE_WITH_CLIENT_MONITOR_PASSWORD_XXX=,,p .rndpwd)

cat > bareos-fd.d/director/bareos-dir.conf <<EOF
Director {
  Name = "bareos-dir"
  Password = "$dir_pwd"
}
EOF

cat > bareos-fd.d/director/bareos-mon.conf <<EOF
Director {
  Name = bareos-mon
  Password = "$mon_pwd"
  Monitor = yes
  Description = "Restricted Director, used by tray-monitor to get the status of this file daemon."
}
EOF

install -o root -m 700 /dev/null $(hostname -s).conf
cat > $(hostname -s).conf <<EOF
Client {
  Name = "$(hostname -s)"
  Address = "$(hostname)"
  Password = "$dir_pwd"
}
EOF

kinit -k $(hostname -s |tr a-z A-Z)\$

smbclient -P //dshs-backup-j1.dshs.local/bareos-client -c "put $(hostname -s).conf"

kdestroy

rm $(hostname -s).conf
