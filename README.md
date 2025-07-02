# Droitwich Spa High School non-Windows policies

## Commissioning a new machine

This is currently a set for FreeBSD machines.  To set up one from scratch (clean install):

```console
# sysrc hostname=my_new_hostname.dshs.local
# tzsetup Europe/London
# mkdir -p /usr/local/etc/sudoers.d /home
# service sshd onekeygen
# echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /usr/local/etc/sudoers.d/domain_admins_nopasswd
# env ASSUME_ALWAYS_YES=yes pkg install sudo py311-ansible git
# cat > /etc/periodic.conf <<EOF
> daily_ansible_pull_github_enable=yes
> daily_ansible_pull_github_repo=droitwichspahigh/ansible-config
> EOF
# . /etc/periodic.conf
# ansible-pull -vU https://github.com/$daily_ansible_pull_github_repo -i hosts all.yml
# pkg set -v 1 pam_mkhomedir sssd2
# kinit my_dshs_domain_admin_username
# net ads join -k
# getcert add-ca -c DSHS.LOCAL -e /usr/local/libexec/certmonger/cepces-submit
# getcert request -c DSHS.LOCAL -T DSHSComputer -I MachineCertificate -k /etc/ssl/private/certmonger.key -f /etc/ssl/certs/certmonger.crt
# 
```

Notes:

- openldap26-client needs rebuilding with GSSAPI option
- If authentication with SSSD doesn't work after net ads join, sv down sssd && net ads leave -k && rm -r /var/db/sss /etc/krb5.keytab && net ads join -k && sv restart sssd

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

## Adding further file shares

Create a ZFS volume for the file share.  You may need to create a mountpoint if it doesn't
appear under the existing ones.

```console
# zfs create backups/archive
# zfs set aclmode=restricted backups/archive
# zfs set aclinherit=passthrough backups/archive
# zfs set mountpoint=/archive backups/archive
# chown 'administrator:domain admins' /archive
# chmod g+ws /archive
```

Optionally set the snapshots to be visible

```console
# zfs set snapdir=visible backups/archive
# cd /archive
# ln -s .zfs/snapshot snapshots
``

In this Ansible tree, edit or create a `smb4_local.conf` for the host and put the details in.

```console
% vim hostfiles/smb4_local.conf/dshs-backup2.dshs.local
```

    [archive]
            vfs objects = zfsacl
            path = /archive
            writeable = Yes

```console
% git commit hostfiles/smb4_local.conf/dshs-backup2.dshs.local
% git push
```

On the host, pull the latest Ansible through:

```console
# sh /usr/local/etc/periodic/daily/132.ansible-pull
# pkill -HUP smbd
```
