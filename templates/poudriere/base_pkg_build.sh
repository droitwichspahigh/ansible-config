#!/bin/sh

srcdir=/poudriere/data/src
# Need the suffix or Poudriere uses builtin manifests
# and refuses to use our tarballs
srcvers="releng-13.2:13.2-RELEASE-dshs"
archs=${1:-amd64 i386}

poudriere=/usr/local/bin/poudriere

mktarball() {
	local arch src version
	arch=$1
	src=$2
	version=${src##*/}

	echo Updating $src

	(cd $src && /usr/local/bin/git pull --ff-only)

	echo Making tarballs for $arch from $src

	mkdir -p $arch-tarballs/$version

	#echo -n Cleaning before...
	#make -C $src/release clean >/dev/null 2>&1
	#make -C $src cleandir cleandir >/dev/null 2>&1
	#echo "...[DONE]"

	echo -n Building world and kernel...
	make -C $src -j 16 buildworld buildkernel TARGET=$arch \
		>$arch-tarballs/$version/buildlog 2>&1 || \
			tail -n 50 $arch-tarballs/$version/buildlog
	make -C $src -j 16 packages TARGET=$arch \
		>>$arch-tarballs/$version/buildlog 2>&1 || \
			tail -n 50 $arch-tarballs/$version/buildlog
	echo "...[DONE]"

	echo -n Building tarballs...
	make -C $src/release -DNOPORTS -DNODOC -DNOPKG -DNOSRC \
		TARGET=$arch ftp >$arch-tarballs/$version/releaselog 2>&1
	echo "...[DONE]"
	rm $arch-tarballs/$version/*.txz
	mv $(make -C $src TARGET_ARCH=$arch -VMAKEOBJDIR)/release/*.txz $(make -C $src TARGET_ARCH=$arch -VMAKEOBJDIR)/release/ftp/MANIFEST $arch-tarballs/$version/
}

mkpjail() {
	local _jname _version _arch _tarball_dir
	_jname=$1
	_version=$2
	_arch=$3
	_tarball_dir=$4

	if $poudriere jail -l | grep -q $_jname; then
		$poudriere jail -u -j $_jname
	else
		$poudriere jail -c -j $_jname -m url=/poudriere/data/scripts/$_arch-tarballs/$_tarball_dir -v $_version
	fi
}

bulkjail() {
	local _jail _packagelists
	_jail=$1

	_packagelists=""

	(cd /usr/ports && /usr/local/bin/git pull --ff-only)

	for l in /usr/local/etc/poudriere.d/pkglist-dshs*; do
		_packagelists="${_packagelists} -f $l"
	done

	$poudriere bulk -j $_jail -p default $_packagelists
}

if [ "$(date +%w)" -eq "6" ]; then
	buildeverything=yes
fi
buildports=yes

for v in ${srcvers}; do
    for a in ${archs}; do
	vdir=${v%:*}
	vver=${v#*:}
	#pjail=$(echo $vdir | sed 's,^[^0-9]*\([0-9]*\)\.\([0-9]*\).*$,\1\2,')$a
	#pjail=FreeBSD:$(echo $vdir | sed 's,^[^0-9]*\([0-9]*\)\..*,\1,'):$a
	pjail=FreeBSD:${vdir%%.*}:$a
	if pgrep -f $pjail; then
		echo Jail $pjail already running, we will not update it now
		continue
	fi
	[ -z "$buildeverything" ] || mktarball $a $srcdir/$vdir
	[ -z "$buildeverything" ] || mkpjail $pjail $vver $a $vdir
	[ -z "$buildports" ] || bulkjail $pjail
    done
done
