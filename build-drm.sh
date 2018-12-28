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
sync="true"
configure="true"
nProc=$(nproc)
clean="false"
useMeson="true"
install="false"
baseConfigCmd="arch-meson"

# Overriding variables if arguments passed
for param in "$@"
do
	if [ "$param" == "32" ]
	then
		architecture="32"
	fi

	if [ "$param" == "nosync" ]
	then
		sync="false"
	fi

	if [ "$param" == "slow" ]
	then
		nProc="1"
	fi

	if [ "$param" == "clean" ]
	then
		clean="true"
	fi

  if [ "$param" == "noconfig" ]
  then
		configure="false"
	fi

	if [ "$param" == "install" ]
	then
		install="true"
	fi

  if [ "$param" == "nomeson" ]
  then
    useMeson="false"
    baseConfigCmd="./configure"
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
if [ "$useMeson" == "false" ]
then # Autogen
  # Options not used
  #		--disable-intel \
  #		--disable-nouveau"
  #
  baseConfigCmd="$baseConfigCmd"
else # Meson
  baseConfigCmd="$baseConfigCmd"
fi

# Setting architecture
if [ "$architecture" == "32" ]; then
  setLibSuffix="32"
  setHost="i686-pc-linux-gnu"

  if [ "$useMeson" == "false" ]
  then
    setBuild="x86_64-pc-linux-gnu"
    # export CC="gcc -m32"
    # export CXX="g++ -m32"
    export CFLAGS="-m32"
    export CXXFLAGS="-m32"
    export LLVM_CONFIG="/usr/bin/llvm-config32"
    export PKG_CONFIG_PATH="/usr/lib32/pkgconfig"
  fi

else
  setLibSuffix=""
  setHost="x86_64-pc-linux-gnu"

	# Enabling 64bit only options
  if [ "$useMeson" == "false" ]
  then # Autogen
    setBuild="x86_64-pc-linux-gnu"
    export CFLAGS="-m64"
    export CXXFLAGS="-m64"
    export LLVM_CONFIG="/usr/bin/llvm-config"
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig"
  fi
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

# Autogen and Configuring
if [ "$useMeson" == "false" ]
then # Autogen
  execCmd="$baseConfigCmd \
                --build=$setBuild \
                --host=$setHost \
                --prefix=$setPrefix \
                --libdir=$setLibdir"
else # Meson
  execCmd="$baseConfigCmd \
                $projectdir\
                $builddir \
                --libdir=$setLibdir \
                -D valgrind=false"
  if [ "$architecture" == "32" ]
  then
    execCmd="$execCmd \
            --cross-file x86-linux-gnu"
  fi
fi

# Launching Configuration and Build
if [ "$useMeson" == "false" ]
then
  if [ "$configure" == "false" ]
  then
    echo "Skipping configuration, building directly."
  else
    echo $projectdir/$execCmd
    $projectdir/$execCmd
  fi
  make -j $nProc
else
  if [ "$configure" == "false" ]
  then
    echo "Skipping configuration, building directly."
  else
    echo $execCmd
    $execCmd
  fi
  ninja -j $nProc -C "$builddir"
fi

make_exitcode=$?

if [ "$make_exitcode" == "0" ]
then
	echo "Build succeeded"

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
