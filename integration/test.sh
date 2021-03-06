#!/bin/bash

rm -rf files-* conf-* md5-*

extraopts=""
p=$(pwd)

go build genfiles.go
go build md5r.go

echo "Setting up (keys)..."
i1=$(syncthing --home conf-1 2>&1 | awk '/My ID/ {print $7}')
echo $i1
i2=$(syncthing --home conf-2 2>&1 | awk '/My ID/ {print $7}')
echo $i2
i3=$(syncthing --home conf-3 2>&1 | awk '/My ID/ {print $7}')
echo $i3

echo "Setting up (files)..."
for i in 1 2 3 ; do
	cat >conf-$i/syncthing.ini <<EOT
[repository]
dir = $p/files-$i

[nodes]
$i1 = 127.0.0.1:22001
$i2 = 127.0.0.1:22002
$i3 = 127.0.0.1:22003

[settings]
gui-enabled = false
listen-address = :2200$i
EOT

	mkdir files-$i
	pushd files-$i >/dev/null
	../genfiles -maxexp 21 -files 400
	touch empty-$i
	../md5r > ../md5-$i
	popd >/dev/null
done

echo "Starting..."
for i in 1 2 3 ; do
	sleep 1
	syncthing --home conf-$i $extraopts &
done

cat md5-* | sort > md5-tot
while true ; do
	read
	echo Verifying...

	conv=0
	for i in 1 2 3 ; do
		pushd files-$i >/dev/null
		../md5r | sort > ../md5-$i
		popd >/dev/null
		if ! cmp md5-$i md5-tot >/dev/null ; then
			echo $i unconverged
		else
			conv=$((conv + 1))
			echo $i converged
		fi
	done

	if [[ $conv == 3 ]] ; then
		kill %1
		kill %2
		kill %3
		exit
	fi
done

