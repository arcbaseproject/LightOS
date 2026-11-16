#!/bin/sh
# Build static LightOS packages into packages/out/<name>-<ver>.tar.gz and write the
# package index baked into the image (rootfs/etc/lpkg/index).
# Package layout: files relative to the install prefix, e.g. bin/lua.
set -e
cd "$(dirname "$0")"
URL=https://github.com/arcbaseproject/LightOS/releases/download/packages
rm -rf out work && mkdir -p out work src

fetch() { # url sha256
  f=src/${1##*/}
  [ -f "$f" ] || curl -sSfL "$1" -o "$f"
  echo "$2  $f" | sha256sum -c --quiet
}

pack() { # name version dir
  tar -C "$3" --owner=0 --group=0 -czf "out/$1-$2.tar.gz" .
}

# lua: built from source, static.
fetch https://www.lua.org/ftp/lua-5.5.1.tar.gz 1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce
tar -xzf src/lua-5.5.1.tar.gz -C work
make -s -C work/lua-5.5.1 linux MYLDFLAGS=-static >/dev/null
mkdir -p work/lua/bin && cp work/lua-5.5.1/src/lua work/lua-5.5.1/src/luac work/lua/bin/
strip work/lua/bin/*
pack lua 5.5.1 work/lua

# jq: upstream ships a static binary.
fetch https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64 \
  "$(curl -sSfL https://github.com/jqlang/jq/releases/download/jq-1.8.2/sha256sum.txt | awk '$2=="jq-linux-amd64"{print $1}')"
mkdir -p work/jq/bin && install -m755 src/jq-linux-amd64 work/jq/bin/jq
pack jq 1.8.2 work/jq

# Index: name version url sha256
mkdir -p ../rootfs/etc/lpkg
for f in out/*.tar.gz; do
  b=${f#out/}; nv=${b%.tar.gz}
  echo "${nv%-*} ${nv##*-} $URL/$b $(sha256sum "$f" | cut -d' ' -f1)"
done > ../rootfs/etc/lpkg/index
cat ../rootfs/etc/lpkg/index
rm -rf work
