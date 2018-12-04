#!/bin/bash
# Determining own folder
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

echo "Beginning building libglvnd..."

# Setting default values
architecture="64"
sync="true"
configure="true"
nProc=$(nproc)
clean="false"
baseConfigCmd="./configure"
install="false"

# Overriding variables if arguments passed
for param in "$@"
do
	if [ "$param" == "32" ]; then
		architecture="32"
	fi

	if [ "$param" == "nosync" ]; then
		sync="false"
	fi

	if [ "$param" == "slow" ]; then
		nProc="1"
	fi

	if [ "$param" == "clean" ]; then
		clean="true"
	fi

  if [ "$param" == "noconfig" ]; then
		configure="false"
	fi

	if [ "$param" == "install" ]; then
		install="true"
	fi
done

# Moving to good directory
cd $DIR/libglvnd

# Force cleaning if needed
if [ "$clean" == "true" ]; then
	echo "Force cleaning because 'clean' is set."
	git clean -xdf
#	baseConfigCmd="./autogen.sh"
fi

# Syncing if needed
if [ "$sync" == "true" ]; then
	echo "Syncing because 'sync' is $sync"
	git pull
fi

# Configuring
# Not used
#
baseConfigCmd="$baseConfigCmd"

# Setting architecture
if [ "$architecture" == "32" ]; then
    export CFLAGS="-m32"
    export CXXFLAGS="-m32"
    export LLVM_CONFIG="/usr/bin/llvm-config32"
    export PKG_CONFIG_PATH="/usr/lib32/pkgconfig"
    setBuild="x86_64-pc-linux-gnu"
    setHost="i686-pc-linux-gnu"
    setLibSuffix="32"
else
    export CFLAGS="-m64"
    export CXXFLAGS="-m64"
    export LLVM_CONFIG="/usr/bin/llvm-config"
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig"
    setBuild="x86_64-pc-linux-gnu"
    setHost="x86_64-pc-linux-gnu"
    setLibSuffix=""
fi

# Setting architecture independant variables for paths
setPrefix="/usr"
setSysconfdir="/etc"
setLibdir="$setPrefix/lib$setLibSuffix"

# autogen.sh
echo "./autogen.sh"
./autogen.sh

# Configuring
mkdir -p $setHost
cd $setHost

# --- Not used ---
#         --enable-shared
#
if [ "$configure" == "false" ]
then
  echo "Skipping configuration, building directly."
else
execCmd="$baseConfigCmd \
        --build=$setBuild \
        --host=$setHost \
        --prefix=$setPrefix \
        --libdir=$setLibdir \
        --sysconfdir=$setSysconfdir"

echo "../$execCmd"
../$execCmd
fi

# Building
make -j $nProc
make_exitcode=$?

if [ "$make_exitcode" == "0" ]; then
	echo "Build succeeded"

	if [ "$install" == "true" ]; 	then
    # We don't need GLES libraries since their stubs will be provided by libglvnd
    sudo rm $setLibdir/libGLESv1_CM.*
    sudo rm $setLibdir/libGLESv2.*

		sudo make install
  fi
else
	echo "make failed and returned exitcode $make_exitcode"
fi
