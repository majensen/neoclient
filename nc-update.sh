#!/bin/bash
set -euo pipefail
# update Neo4j::Client build directory from libneo4j-client
# run in top-level of work tree or run with working dir as arg 1
NCFILES="Makefile.am autogen.sh configure.ac"
#LIBFILES="Makefile.am neo4j-client.pc.in"
LIBSRCFILES="Makefile.am *.c *.h *.in"
LIBNEO4J_CLIENT=${1:-}
: ${LIBNEO4J_CLIENT:=libneo4j-client}

mkdir -p build/lib/src 2> /dev/null
cp -aR $LIBNEO4J_CLIENT/build-aux build
echo "SUBDIRS = src" > build/lib/Makefile.am
for f in $NCFILES
do
  cp $LIBNEO4J_CLIENT/$f build
done
for f in $LIBSRCFILES
do 
  cp $LIBNEO4J_CLIENT/lib/src/$f build/lib/src
done
pushd build
sed -ie "/SUBDIRS.*shell/d" Makefile.am
sed -ie "/hidden/s/-fvisibility=hidden//;/warning-option/s/-Wno-unknown-warning-option//;/stringop-truncation/s/-W.*stringop-truncation//" configure.ac
sed -e "/^DX/d;/AC_CONFIG_FILES/q" configure.ac > cac
cat <<EOF >> cac
	Makefile \\
	lib/Makefile \\
	lib/src/Makefile \\
	lib/src/neo4j-client.h
])
AC_OUTPUT
EOF
mv cac configure.ac
popd
pushd build/lib/src
sed -ie "/^include_HEADERS/c\\
include_HEADERS = neo4j-client.h atomic.h buffering_iostream.h chunking_iostream.h client_config.h connection.h deserialization.h iostream.h job.h logging.h memory.h messages.h metadata.h network.h print.h posix_iostream.h render.h result_stream.h ring_buffer.h serialization.h thread.h tofu.h transaction.h uri.h util.h values.h\\
" Makefile.am
popd
pushd build
rm *.ame *.ace lib/src/*.ame
./autogen.sh
automake
rm -rf autom4te.cache
popd
