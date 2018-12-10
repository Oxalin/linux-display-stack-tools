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
glvnd="true"
architecture="64"
sync="true"
configure="true"
nProc=$(nproc)
useMeson="false"
clean="false"
baseConfigCmd="./configure"
install="false"
# Folder in which the GL, GLES and EGL files will be installed

# Overriding variables if arguments passed
for param in "$@"
do
	if [ "$param" == "noglvnd" ]; then
		glvnd="false"
	fi

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

  if [ "$param" == "meson" ]
  then
    useMeson="true"
    baseConfigCmd="arch-meson"
  fi
done

# Moving to good directory
projectdir="$DIR/mesa"
cd $projectdir

# Force cleaning if needed
if [ "$clean" == "true" ]; then
	echo "Force cleaning because 'clean' is set."
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
if [ "$sync" == "true" ]; then
	echo "Syncing because 'sync' is $sync"
	git pull
fi

# Configuring
# Not used
#		--enable-static \
#		--with-gl-lib-name=mesa \
#		--enable-sysfs \
#		--enable-glx
#		--enable-gallium-osmesa \
#
if [ "$useMeson" == "false" ]
then
  baseConfigCmd="$baseConfigCmd \
                --enable-gles1 \
                --enable-gles2 \
                --enable-egl \
                --enable-gallium-extra-hud \
                --enable-dri \
                --enable-dri3 \
                --disable-xvmc \
                --enable-llvm \
                --enable-llvm-shared-libs \
                --enable-shared-glapi \
                --enable-gbm \
                --enable-texture-float \
                --enable-xa \
                --enable-nine \
                --enable-vdpau \
                --enable-omx-bellagio \
                --enable-va \
                --enable-glx-tls \
                --enable-debug \
                --enable-libunwind \
                --with-gallium-drivers=nouveau,virgl,svga,swrast \
                --with-vulkan-drivers=radeon,intel \
                --with-dri-drivers=i965 \
                --with-platforms=x11,drm,wayland,surfaceless"
else
  baseConfigCmd="$baseConfigCmd \
                -D gles1=true \
                -D gles2=true \
                -D egl=true \
                -D gallium-extra-hud=true \
                -D glx=dri \
                -D dri3=true \
                -D gallium-xvmc=false \
                -D llvm=true \
                -D shared-glapi=true \
                -D gbm=true \
                -D gallium-xa=true \
                -D gallium-nine=true \
                -D gallium-vdpau=true \
                -D gallium-omx=bellagio \
                -D gallium-va=true \
                -D libunwind=true \
                -D gallium-drivers=radeonsi,nouveau,virgl,svga,swrast \
                -D vulkan-drivers=amd,intel \
                -D dri-drivers=i965 \
                -D platforms=x11,wayland,drm,surfaceless \
                -D swr-arches=avx,avx2 \
                -D osmesa=gallium"
fi



# Check if glvnd support is enabled
if [ "$glvnd" == "true" ]; then
  if [ "$useMeson" == "false" ]
  then
    baseConfigCmd="$baseConfigCmd --enable-libglvnd"
  else
    baseConfigCmd="$baseConfigCmd -D glvnd=true"
  fi
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
  then
    setBuild="x86_64-pc-linux-gnu"
    export CFLAGS="-m64"
    export CXXFLAGS="-m64"
    export LLVM_CONFIG="/usr/bin/llvm-config"
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig"
    baseConfigCmd="$baseConfigCmd \
                  --enable-lmsensors \
                  --enable-opencl \
                  --enable-opencl-icd"
  else
    baseConfigCmd="$baseConfigCmd \
                  -D lmsensors=true \
                  -D gallium-opencl=icd"
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
then
  # --- List of options not used ---
  #
  execCmd="$baseConfigCmd \
          --build=$setBuild \
          --host=$setHost \
          --prefix=$setPrefix \
          --libdir=$setLibdir \
          --sysconfdir=$setSysconfdir \
          --with-omx-bellagio-libdir=$setLibdir/bellagio \
          --with-d3d-libdir=$setLibdir/d3d \
          --with-dri-driverdir=$setLibdir/dri \
          --with-vdpau-libdir=$setLibdir/vdpau  \
          --with-va-libdir=$setLibdir/dri "
else
  # --- List of options not used ---
  #
  # -D omx-libs-path=$setLibdir/bellagio \
  # -D d3d-drivers-path=$setLibdir/d3d \
  # -D dri-drivers-path=$setLibdir/dri \
  # -D vdpau-libs-path=$setLibdir/vdpau  \
  # -D va-libs-path=$setLibdir/dri \
  execCmd="$baseConfigCmd \
          $projectdir \
          $builddir \
          --libdir=$setLibdir \
          --sysconfdir=$setSysconfdir \
          -D b_lto=false \
          -D b_ndebug=true \
          -D valgrind=false"
  if [ "$architecture" == "32" ]
  then
    execCmd="$execCmd \
            --cross-file x86-linux-gnu"
  fi
fi

# Configuring and Building
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

  # Let's build and reinstall libglvnd if needed
  if [ "$glvnd" == "true" ]
  then
    echo "Launching libglvnd build: $DIR/build-libglvnd.sh $@"
    $DIR/build-libglvnd.sh $@
  fi
else
	echo "make failed and returned exitcode $make_exitcode"
fi
