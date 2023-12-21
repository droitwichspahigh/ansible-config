#!/bin/sh

preformat()
{

	echo "<pre>"
	IFS='
'
	while read line; do
		printf "%s\n" "$line";
	done
	echo "</pre>"
}

tag()
{
	local _tag

	_tag=$1
	shift

	echo "<$_tag>$*</$_tag>"
}

output() {

	echo "<html><head><title>zpool status: $(hostname)</title></head>"
	echo "<body>"

	tag h1 $(hostname)

	tag h2 zpool status:
	zpool status -DTd | preformat

	tag h2 filesystems:
	zfs list | preformat

	echo "</body></html>"
}

while :; do
	output > /usr/local/www/apache24/data/zpool-status.html
	sleep 10
done
