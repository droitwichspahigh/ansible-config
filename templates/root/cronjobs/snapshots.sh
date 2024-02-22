#!/bin/sh
#
# $BayOfRum: snapshots.sh,v 1.2 2012/06/24 15:13:57 root Exp $
#

usage () {
        cat <<EOF
usage: /bin/sh $0 schedule [filesystem [filesystem ...]]

Takes recursive snapshots of specified ZFS filesystems on a specified basis.

Cleans them up according to builtin retention policy, shown below, for example
each hourly snapshot is limited to 26 snapshots.

Yearly is likely excessive.

schedule: hourly (26), daily (9), weekly (4), monthly (3), yearly (1)

filesystem: defaults to all ZFS filesystems available from 'zpool list'
EOF
	exit 1
}

# check pool is ready
check_ready()
{
	local _fs _pool

	_fs=$1

	_pool=${fs%%/*}

	/sbin/zpool status $_pool | \
	    /usr/bin/egrep -q "resilvered|completed|none requested|repaired|canceled"
}

# takesnap snapshot_name
takesnap()
{
	local _fs _snapname

	_fs=$1
	_snapname=$2

	if check_ready $_fs; then
	    /sbin/zfs snapshot -r $_fs@$_snapname
	fi
}

# cleansnap snap_prefix number_to_keep
cleansnap()
{
	local _fs _snapprefix _retention_number

	_fs=$1
	_snapprefix=$2
	_retention_number=$3

	/sbin/zfs list -t snapshot -o name | \
	    /usr/bin/grep ^$_fs@$_snapprefix | \
	    /usr/bin/sort -r | \
	    /usr/bin/tail -n +$_retention_number | \
	    /usr/bin/xargs -n 1 /sbin/zfs destroy -r
}

instruction=$1
shift
filesystems=${1+"$@"}
: ${filesystems:=$(/sbin/zpool list -Ho name)}

for fs in $filesystems; do
	case $instruction in
	daily)
		takesnap $fs AutoD-`date +"%F"` && \
		    cleansnap $fs AutoD- 9
		;;
	hourly)
		takesnap $fs AutoH-`date +"%FT%H%M"` && \
		    cleansnap $fs AutoH- 26
		;;
	weekly)
		takesnap $fs AutoW-`date +"%Y-%U"` && \
		    cleansnap $fs AutoW- 4
		;;
	monthly)
		takesnap $fs AutoM-`date +"%Y-%m"` && \
		    cleansnap $fs AutoM- 3
		;;
	yearly)
		takesnap $fs AutoY-`date +"%Y"` && \
		    cleansnap $fs AutoY- 1
		;;
	*)
		usage
		;;
	esac
done
