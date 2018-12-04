#!/bin/bash
# Determining own folder
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Setting default values
architecture="64"
sync=true
nProc=$(nproc)
clean=false
baseConfigCmd="./configure"
driver="ati"

# Overriding variables if arguments passed
for param in "$@"
do
	if [ "$param" == "32" ]
	then
		architecture="32"
	fi

	if [ "$param" == "nosync" ]
	then
		sync=false
	fi

	if [ "$param" == "slow" ]
	then
		nProc="1"
	fi

	if [ "$param" == "clean" ]
	then
		clean=true
	fi

	if [ "$param" == "install" ]
	then
		install=true
	fi

	if [ "$param" == "amdgpu" ]
	then
		driver="amdgpu"
	fi
done

# Moving to good directory
cd $DIR/xf86-video-$driver

# Force cleaning if needed
if [ "$clean" == "true" ]
then
	echo "Force cleaning because 'clean' is $clean"
	git clean -xdf
	baseConfigCmd="./autogen.sh"
fi

# Syncing if needed
if [ "$sync" == "true" ]
then
	echo "Syncing because 'sync' is $sync"
	git pull
fi

# Configuring
# Not used
#	
baseConfigCmd="$baseConfigCmd \
		"

# Setting architecture
if [ "$architecture" == "32" ]
then
	export CFLAGS="-m32"
	export CXXFLAGS="-m32"
	export LLVM_CONFIG="/usr/bin/llvm-config32"
	export PKG_CONFIG_PATH="/usr/lib32/pkgconfig"
	setBuild="x86_64-pc-linux-gnu"
	setHost="i686-pc-linux-gnu"
	setLibdir="/usr/lib32/"
#	execPrefixInstallDir="$HOME/ddx"
#	PrefixInstallDir="$HOME/ddx"
else
	export CFLAGS="-m64"
	export CXXFLAGS="-m64"
	export LLVM_CONFIG="/usr/bin/llvm-config"
	export PKG_CONFIG_PATH="/usr/lib/pkgconfig"
	setBuild="x86_64-pc-linux-gnu"
	setHost="x86_64-pc-linux-gnu"
	setLibdir="/usr/lib/"
#	execPrefixInstallDir="$HOME/ddx"
#	PrefixInstallDir="$HOME/ddx"
fi

mkdir -p $setHost
cd $setHost

# Building
execCmd="$baseConfigCmd --build=$setBuild --host=$setHost --libdir=$setLibdir"

echo "../$execCmd"
../$execCmd
make -j $nProc
make_exitcode=$?

if [ "$make_exitcode" == "0" ]
then
	echo "make succeeded"
	if [ "$install" == "true" ]
	then
		sudo make install
	fi
else
	echo "make failed and returned exitcode $make_exitcode"
fi

