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

# Overriding variables if arguments passed
for param in "$@"
do
  if [ "$param" == "32" ]; then
    architecture="32"
  elif [ "$param" == "both" ]; then
    architecture="both"
  else
    program="$program $param"
  fi
done

# Setting architecture
if [ "$architecture" == "32" ]; then
  setHost="i686-pc-linux-gnu"
  export LD_LIBRARY_PATH=~/projects/display/mesa/build/$setHost/lib32/
  export LIBGL_DRIVERS_PATH=$LD_LIBRARY_PATH/gallium/
  export EGL_DRIVERS_PATH=$LD_LIBRARY_PATH/egl/
elif [ "$architecture" == "both" ]; then
  setHost="i686-pc-linux-gnu"
  LD_LIBRARY32_PATH=~/projects/display/mesa/$setHost/lib32/
  setHost="x86_64-pc-linux-gnu"
  LD_LIBRARY64_PATH=~/projects/display/mesa/$setHost/lib/
  export LD_LIBRARY_PATH="$LD_LIBRARY64_PATH:$LD_LIBRARY32_PATH"
  export LIBGL_DRIVERS_PATH="$LD_LIBRARY64_PATH/gallium/:$LD_LIBRARY32_PATH/gallium/"
  export EGL_DRIVERS_PATH="$LD_LIBRARY64_PATH/egl/:$LD_LIBRARY32_PATH/egl/"
else
  setHost="x86_64-pc-linux-gnu"
  export LD_LIBRARY_PATH=~/projects/display/mesa/$setHost/lib/
  export LIBGL_DRIVERS_PATH=$LD_LIBRARY_PATH/gallium/
  export EGL_DRIVERS_PATH=$LD_LIBRARY_PATH/egl/
fi

#export LD_LIBRARY_PATH=~/projects/display/mesa/lib32/
echo $LD_LIBRARY_PATH
echo $LIBGL_DRIVERS_PATH
echo $EGL_DRIVERS_PATH
echo "launching program: $program"
#ldd $program
${program}
