# Droitwich Spa High School non-Windows policies

## Commissioning a new machine

This is currently a set for FreeBSD machines.  To set up one from scratch (clean install):

```console
# sysrc hostname=my_new_hostname.dshs.local
# tzsetup Europe/London
# mkdir -p /usr/local/etc/sudoers.d
# echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /usr/local/etc/sudoers.d/domain_admins_nopasswd
# env ASSUME_ALWAYS_YES=yes pkg install sudo py39-ansible git
# cat > /etc/periodic.conf <<EOF
> daily_ansible_pull_github_enable=yes
> daily_ansible_pull_github_repo=droitwichspahigh/ansible-config
> EOF
# . /etc/periodic.conf
# ansible-pull -vU https://github.com/$daily_ansible_pull_github_repo -i hosts all.yml
# pkg set -v 1 pam_mkhomedir sssd-smb
# kinit my_dshs_domain_admin_username
# net ads join -k
# 
```

Notes:

- Sadly right now ldb needs building from ports with version 2.3 [1]
- openldap26-client needs rebuilding with GSSAPI option
- If authentication with SSSD doesn't work after net ads join, sv down sssd && net ads leave -k && rm -r /var/db/sss /etc/krb5.keytab && net ads join -k && sv restart sssd

[1] https://bugs.freebsd.org/bugzilla/attachment.cgi?id=241305

## Replacing a failed hard drive

First find out the failed hard drive

```console
# zpool status
```

You should be able to identify it on the machine by the one that isn't blinking.  If you're not sure, probably not a great idea to yank one out because that'll fault the whole pool.

Put the new HDD in, and identify it with `gpart show`.  It'll either be blank or have Windows partitions on it.

Then, add the FreeBSD partitions for it- try to match the existing ones on the other drives.  Don't oversize the partitions.

```console
# ls /dev/diskid                    # pick the new drive out of there
# diskid=diskid/[[whatever_diskid_you_chose]]
# poolname=whatever_the_zfs_pool_is_called
# deaddisk=name_or_id_of_the_dead_disk_from_zpool_status
# gpart destroy -F $diskid          # goes without saying... please check it really is the right one!
# gpart create -s gpt $diskid       # may not be necessary if it already has a GPT
# gpart add -s 512k -t freebsd-boot $diskid
# gpart add -s [[size of the others]] -t freebsd-zfs $diskid
# gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $diskid
# zpool replace $poolname $deaddisk ${diskid}p2     # replace the dead disk with partition 2 on the new one
```

Leave it to resilver and you should be good.  Uptime-Kuma will show green for the server once the resilver is finished.
