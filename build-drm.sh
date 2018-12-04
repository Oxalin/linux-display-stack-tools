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
configure=true
nProc=$(nproc)
clean=false
useMeson=false
install=false
baseConfigCmd="./configure"

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

  if [ "$param" == "noconfig" ]
  then
		configure=false
	fi

	if [ "$param" == "install" ]
	then
		install=true
	fi

  if [ "$param" == "meson" ]
  then
    useMeson=true
    baseConfigCmd="arch-meson"
  fi
done

# Moving to good directory
projectdir="$DIR/drm"
cd $projectdir

# Force cleaning if needed
if [ "$clean" == "true" ]
then
	echo "Force cleaning because 'clean' is $clean"
	git clean -xdf

  #if using autotool
  if [ "$useMeson" == "false" ]
  then
    baseConfigCmd="./autogen.sh"
  else
#    baseConfigCmd="$baseConfigCmd --reconfigure"
    echo "Keep going"
  fi
fi

# Syncing if needed
if [ "$sync" == "true" ]
then
	echo "Syncing because 'sync' is $sync"
	git pull
fi

# Configuring
# Not used
#		--disable-intel \
#		--disable-nouveau"
#
# baseConfigCmd="$baseConfigCmd"

# Setting architecture
if [ "$architecture" == "32" ]
then
	export CFLAGS="-m32"
	export CXXFLAGS="-m32"
	export LLVM_CONFIG="/usr/bin/llvm-config32"
	export PKG_CONFIG_PATH="/usr/lib32/pkgconfig"
	setBuild="x86_64-pc-linux-gnu"
	setHost="i686-pc-linux-gnu"
  setLibSuffix="32"
#	execPrefixInstallDir="$HOME/dri"
#	PrefixInstallDir="$HOME/dri"
else
	export CFLAGS="-m64"
	export CXXFLAGS="-m64"
	export LLVM_CONFIG="/usr/bin/llvm-config"
	export PKG_CONFIG_PATH="/usr/lib/pkgconfig"
	setBuild="x86_64-pc-linux-gnu"
	setHost="x86_64-pc-linux-gnu"
  setLibSuffix=""
#	execPrefixInstallDir="$HOME/dri"
#	PrefixInstallDir="$HOME/dri"
fi

# Setting architecture independant variables for paths
setPrefix="/usr"
setSysconfdir="/etc"
setLibdir="$setPrefix/lib$setLibSuffix"

builddir="$projectdir/build/$setHost"
if [ "$useMeson" == "false" ]
then
  mkdir -p $builddir
  cd $builddir
fi

# Building
#execConfigCmd="$baseConfigCmd --build=$setBuild --host=$setHost --libdir=$setLibdir --exec-prefix=$execPrefixInstallDir --prefix=$PrefixInstallDir"
if [ "$useMeson" == "false" ]
then
  execConfigCmd="$baseConfigCmd \
                --build=$setBuild \
                --host=$setHost \
                --prefix=$setPrefix \
                --libdir=$setLibdir"
else
  execConfigCmd="$baseConfigCmd \
                $projectdir\
                $builddir \
                --libdir=$setLibdir \
                -D valgrind=false"
fi

# Configuring and Building
if [ "$useMeson" == "false" ]
then
  if [ "$configure" == "false" ]
  then
    echo "Skipping configuration, building directly."
  else
    echo $projectdir/$execConfigCmd
    $projectdir/$execConfigCmd
  fi
  make -j $nProc
else
  if [ "$configure" == "false" ]
  then
    echo "Skipping configuration, building directly."
  else
    echo $execConfigCmd
    $execConfigCmd
  fi
  ninja -j $nProc -C "$builddir"
fi

make_exitcode=$?

if [ "$make_exitcode" == "0" ]
then
	echo "make succeeded"
	if [ "$install" == "true" ]
	then
    if [ "$useMeson" == "false" ]
		then
      sudo make install
    else
      sudo ninja -C $builddir install
    fi
	fi
else
	echo "make failed and returned exitcode $make_exitcode"
fi
