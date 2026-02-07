#!/bin/sh

# This script takes a zfs snapshot of all mounted ZFS filesystems for live
# backup purposes.  Most database software is fine with backups from snapshots
# so this will enable those to be rescued without issue.
#
# Might add BSD FFS snapshots at some point but feels pointless as most
# use SUJ anyway which disables them.

args=$(getopt r $*)
if [ $? -ne 0 ]; then
	echo "Usage: $0 [-r] destination_mountpoint"
	exit 2
fi
set -- $args

while :; do
	case "$1" in
	-r)
		ropt=yes
		shift
		;;
	--)
		shift; break;
		;;
	esac
done

if [ -n "$ropt" ]; then
	# Let's undo what we did earlier
	
	if [ ! -d /zfs_vss_copy ]; then
		echo "Can't undo what was never done..."
		exit 1
	fi

	snapname=$(mount |grep /zfs_vss_copy\  | tr @ \  | cut -d \  -f 2)

	for pool in $(zpool list -Ho name); do
		zfs release -r zfs_vss $pool@$snapname
	done

	rmdir /zfs_vss_copy

	exit 0
fi

snapname="zfs_vss-$(date +%Y%m%d%H%M%S)"

# Let's do a sanity check and bail if unsure

if zfs list -t snapshot -o name | grep -q $snapname; then
	echo "Snapshots exist with name $snapname, please investigate"
	exit 1
fi

if ! mkdir /zfs_vss_copy; then
	echo "Destination dir /zfs_vss_copy already exists, bailing"
	exit 1
fi

# Get the zpools and snapshot

for pool in $(zpool list -Ho name); do
	zfs snapshot -r $pool@$snapname
	zfs hold -r zfs_vss $pool@$snapname
	zfs destroy -dr $pool@$snapname
done

# Remount the snapshots in temporary area

mount -t zfs | while read fs _junk mountpoint options; do
	mount -t zfs $fs@$snapname /zfs_vss_copy$mountpoint
done
