# Droitwich Spa High School non-Windows policies

This is currently a set for FreeBSD machines.  To set up one from scratch (clean install):

```console
# sysrc hostname=my_new_hostname.dshs.local
# tzsetup Europe/London
# mkdir -p /usr/local/etc/sudoers.d
# echo "$(whoami) ALL=(ALL:ALL) NOPASSWD: ALL" > /usr/local/etc/sudoers.d/temp
# env ASSUME_ALWAYS_YES=yes pkg install sudo py39-ansible
# install -m 600 /dev/null /etc/periodic.conf
# cat > /etc/periodic.conf <<EOF
> daily_ansible_pull_github_enable=yes
> daily_ansible_pull_github_token=make_a_github_token_or_steal_it_from_periodic.conf_on_dshs-hv06
> daily_ansible_pull_github_repo=droitwichspahigh/ansible-config
> EOF
# . /etc/periodic.conf
# ansible-pull https://$daily_ansible_pull_github_token@github.com/$daily_ansible_pull_github_repo
# pkg set -v 1 pam_mkhomedir sssd-smb
# kinit my_dshs_domain_admin_username
# net ads join -k
# 
```

Notes:

- Sadly right now ldb needs building from ports with version 2.3 [1]
- openldap26-client needs rebuilding with GSSAPI option

[1] https://bugs.freebsd.org/bugzilla/attachment.cgi?id=241305
