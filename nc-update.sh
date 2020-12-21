#!/bin/bash
# update Neo4j::Client build directory from libneo4j-client
# run in top-level of work tree
NCFILES="Makefile.am autogen.sh configure.ac config.h.in"
#LIBFILES="Makefile.am neo4j-client.pc.in"
LIBSRCFILES="Makefile.am *.c *.h *.in"

mkdir -p build/lib/src 2> /dev/null
cp -aR libneo4j-client/build-aux build/build-aux
echo "SUBDIRS = src" > build/lib/Makefile.am
for f in $NCFILES
do
  cp libneo4j-client/$f build
done
# for f in $LIBFILES
# do
#   cp libneo4j-client/lib/$f build/lib
# done
for f in $LIBSRCFILES
do 
  cp libneo4j-client/lib/src/$f build/lib/src
done
pushd build
sed -ie "/SUBDIRS.*shell/d" Makefile.am
sed -e "/^DX/d;/AC_CONFIG_FILES/q" configure.ac > cac
cat <<EOF >> cac
	Makefile \\
	lib/Makefile \\
	lib/src/Makefile \\
])
AC_OUTPUT
EOF
mv cac configure.ac
./autogen.sh
popd
