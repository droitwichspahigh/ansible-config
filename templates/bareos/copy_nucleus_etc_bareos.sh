#!/bin/sh

printf '%s\n%s\n%s\n%s' 'restore client=dshs-nucleus restoreclient=dshs-backup-j1 add_prefix=/usr/local/etc/bareos/nucleus-etc strip_prefix=/usr/local/etc select current' 'mark /usr/local/etc/bareos' 'done' 'yes'| /usr/local/sbin/bconsole
