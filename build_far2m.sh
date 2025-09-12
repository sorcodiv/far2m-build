#!/bin/sh
#set -x

if [ ! -d "far2m" ]; then echo "far2m/ not found" && exit 1; fi
if [ ! -d "luafar2m" ]; then echo "luafar2m/ not found" && exit 1; fi

REPO_DIR=$GITHUB_WORKSPACE
if [ -z $REPO_DIR ]; then REPO_DIR=.; fi
if [ -z $SAVE_SRC ]; then SAVE_SRC="NO"; fi
BUILD_DIR=_build
DISTRO=$(awk -F= '/^ID=/ {print $2}' /etc/os-release)
MACHINE=$(uname -m)
TOUCH_DATE=$(git -C $REPO_DIR/far2m show --no-patch --format=%cd --date=format:'%Y-%m-%d %H:%M:%S' HEAD)
FAR2M_DATE=$(git -C $REPO_DIR/far2m show --no-patch --format=%cd --date=format:%y%m%d HEAD)
FAR2M_COMMIT=$(git -C $REPO_DIR/far2m rev-parse --short HEAD)
LUAPLG_DATE=$(git -C $REPO_DIR/luafar2m show --no-patch --format=%cd --date=format:%y%m%d HEAD)
LUAPLG_COMMIT=$(git -C $REPO_DIR/luafar2m rev-parse --short HEAD)

if [ "$SAVE_SRC" = "YES" ]; then
  rm -rf $REPO_DIR/far2m/$BUILD_DIR
  rm -rf $REPO_DIR/luafar2m/$BUILD_DIR
  zip -r "far2m-src-$FAR2M_DATE-$FAR2M_COMMIT.zip" far2m >/dev/null
  zip -r "luafar2m-src-$LUAPLG_DATE-$LUAPLG_COMMIT-(far2m-$FAR2M_DATE-$FAR2M_COMMIT).zip" luafar2m >/dev/null
fi

PLG_COLORER="-DCOLORER=no"
PLG_HIGHLIGHT="-DHIGHLIGHT=yes"
PLG_POLYGON="-DPOLYGON=yes"
PLG_WX="-DUSEWX=yes"
CMAKE_OPTS=""
CP_OPTS=""

case $DISTRO in
  alpine) LIBC=musl
    CODENAME=$DISTRO
  ;;
  debian|ubuntu) LIBC=glibc
    CODENAME=$(lsb_release -c | awk '{print $2}')
  ;;
  *) echo "Not supported"; exit 1
esac

if [ "$LIBC" = "glibc" ]; then
  EXCLUDE_LIB="libdl.so.2|libpthread.so.0|libstdc\+\+.so.6|libgcc_s.so.1|libc.so.6|libm.so.6|libresolv.so.2|librt.so.1|libX11.so.6|libxcb.so.1|libXau.so.6|libXdmcp.so.6|libbsd.so.0"
  CP_OPTS="--preserve=timestamps"
  if [ "$CODENAME" = "focal" ]; then
    PLG_COLORER="-DCOLORER=yes"
  fi
elif [ "$LIBC" = "musl" ]; then
  EXCLUDE_LIB="ld-musl-$MACHINE.so.1|libstdc\+\+.so.6|libgcc_s.so.1|libc.musl-$MACHINE.so.1"
  CMAKE_OPTS="-DMUSL=ON -DTAR_LIMITED_ARGS=ON"
  PLG_COLORER="-DCOLORER=no"
  PLG_HIGHLIGHT="-DHIGHLIGHT=yes"
  PLG_POLYGON="-DPOLYGON=no"
  PLG_WX="-DUSEWX=no"
fi

copy_dependencies()
{
  file=$1
  for lib in $(ldd $file | grep "=> /" | awk '{print $3}' | grep -v -E $EXCLUDE_LIB) ; do
    cp -L $CP_OPTS $lib $(dirname $file)
    if [ -z $CP_OPTS ]; then touch -c -m -r $lib $(dirname $file)/$(basename $lib); fi
  done
}

patch_lib()
{
  file=$1
  cnt=0
  for lib in $(ldd $file | grep "=> /" | awk '{print $3}' | grep -v -E $EXCLUDE_LIB) ; do
    cnt=$(( cnt + 1 ))
    break
  done
  if [ $cnt -gt 0 ]; then
    patchelf --remove-rpath $file
    patchelf --set-rpath "\$ORIGIN" $file
    touch -c -m --date "$TOUCH_DATE" $file
  fi
}

chmod 775 $REPO_DIR/far2m/packaging/debian/copyright/generate.pl
chmod 775 $REPO_DIR/far2m/python/src/build.sh

rm -rf $REPO_DIR/far2m/$BUILD_DIR
rm -rf $REPO_DIR/luafar2m/$BUILD_DIR
mkdir -p $REPO_DIR/far2m/$BUILD_DIR
mkdir -p $REPO_DIR/luafar2m/$BUILD_DIR

cmake -S $REPO_DIR/far2m -B$REPO_DIR/far2m/$BUILD_DIR -DLEGACY=no -DCALC=yes $PLG_COLORER $PLG_WX $CMAKE_OPTS -DNETCFG=no -DPYTHON=no -DCMAKE_BUILD_TYPE=Release
if [ $? -ne 0 ]; then exit 1; fi

cmake --build $REPO_DIR/far2m/$BUILD_DIR -- -j$(nproc)
if [ $? -ne 0 ]; then exit 1; fi

cmake -S $REPO_DIR/luafar2m -B$REPO_DIR/luafar2m/$BUILD_DIR $PLG_HIGHLIGHT $PLG_POLYGON -DLF4ED=no -DLFHISTORY=no -DLFTMP=no -DLUAPANEL=no -DCMAKE_BUILD_TYPE=Release
if [ $? -ne 0 ]; then exit 1; fi

cmake --build $REPO_DIR/luafar2m/$BUILD_DIR -- -j$(nproc)
if [ $? -ne 0 ]; then exit 1; fi

rex_onig_so=$(find /usr/lib /usr/local -name rex_onig.so 2>/dev/null | tail -n 1)

if [ ! -z $rex_onig_so ]; then
  if [ "$PLG_HIGHLIGHT" = "-DHIGHLIGHT=yes" ]; then
    sed -i '1ipackage.cpath = package.cpath .. ";"..win.GetEnv("FARHOME").."/rex_onig.so"' $REPO_DIR/luafar2m/$BUILD_DIR/install/highlight/plug/highlight.lua
    sed -i '1ipackage.cpath = package.cpath .. ";"..win.GetEnv("FARHOME").."/rex_onig.so"' $REPO_DIR/luafar2m/$BUILD_DIR/install/lfsearch/plug/lfs_common.lua
    if [ "$PLG_COLORER" = "-DCOLORER=no" ]; then
      mv $REPO_DIR/luafar2m/$BUILD_DIR/install/highlight $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/highlight
    fi
  fi
fi
if [ "$PLG_POLYGON" = "-DPOLYGON=yes" ]; then
  mv $REPO_DIR/luafar2m/$BUILD_DIR/install/polygon $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/polygon
fi
mv $REPO_DIR/luafar2m/$BUILD_DIR/install/lfsearch $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/lfsearch

find $REPO_DIR/far2m/$BUILD_DIR/install/ -type f -exec touch -c -m --date "$TOUCH_DATE" {} \;
for link in $(find $REPO_DIR/far2m/$BUILD_DIR/install/ -type l) ; do touch -h -c -m -r $(readlink -f $link) $link; done
find $REPO_DIR/far2m/$BUILD_DIR/install/ -type d -exec touch -c -m --date "$TOUCH_DATE" {} \;

if [ ! -z $rex_onig_so ]; then
  cp -L $CP_OPTS $rex_onig_so $REPO_DIR/far2m/$BUILD_DIR/install/
  if [ -z $CP_OPTS ]; then touch -c -m -r $rex_onig_so $REPO_DIR/far2m/$BUILD_DIR/install/rex_onig.so; fi
fi
cp -L $CP_OPTS $(find /usr/lib -name libluajit-5.1.so 2>/dev/null) $REPO_DIR/far2m/$BUILD_DIR/install/
if [ -z $CP_OPTS ]; then touch -c -m -r $(find /usr/lib -name libluajit-5.1.so 2>/dev/null) $REPO_DIR/far2m/$BUILD_DIR/install/libluajit-5.1.so; fi

if [ "$LIBC" = "musl" ]; then
  patchelf --replace-needed libluajit-5.1.so.2 libluajit-5.1.so $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/luafar/luamacro/plug/luamacro.far-plug-wide
  touch -c -m --date "$TOUCH_DATE" $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/luafar/luamacro/plug/luamacro.far-plug-wide
  patchelf --replace-needed libluajit-5.1.so.2 libluajit-5.1.so $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/luafar/hlfviewer/plug/hlfviewer.far-plug-wide
  touch -c -m --date "$TOUCH_DATE" $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/luafar/hlfviewer/plug/hlfviewer.far-plug-wide
  copy_dependencies $REPO_DIR/far2m/$BUILD_DIR/install/far2m
  patch_lib $REPO_DIR/far2m/$BUILD_DIR/install/far2m
  if [ ! -z $rex_onig_so ]; then
    copy_dependencies $REPO_DIR/far2m/$BUILD_DIR/install/rex_onig.so
    patch_lib $REPO_DIR/far2m/$BUILD_DIR/install/rex_onig.so
  fi
else
  for file in $(find $REPO_DIR/far2m/$BUILD_DIR/install/ -type f) ; do
    if file $file | grep ELF > /dev/null; then
      copy_dependencies $file
      patch_lib $file
      for lib in $(ldd $file | grep "=> /" | awk '{print $3}' | grep -v -E $EXCLUDE_LIB) ; do
        patch_lib $(dirname $file)/$(basename $lib)
      done
    fi
  done
fi

#remove libxml2.so
if [ -f $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/colorer/plug/colorer.far-plug-wide ]; then
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/colorer/plug/libicudata.so.*
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/colorer/plug/libicuuc.so.*
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/colorer/plug/liblzma.so.*
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/colorer/plug/libxml2.so.*
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/colorer/plug/libz.so.*
fi
if [ -f $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/multiarc/plug/libarchive.so.* ]; then
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/multiarc/plug/libicudata.so.*
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/multiarc/plug/libicuuc.so.*
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/multiarc/plug/liblzma.so.*
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/multiarc/plug/libxml2.so.*
  rm $REPO_DIR/far2m/$BUILD_DIR/install/Plugins/multiarc/plug/libz.so.*
fi

current_path="$(realpath .)"
cd $REPO_DIR/far2m/$BUILD_DIR/install
zip --symlinks -m -r "$current_path/far2m-bin-$FAR2M_DATE-$FAR2M_COMMIT-$MACHINE-$LIBC-libs.zip" *.so.* Plugins/NetRocks/plug/*.so.* -x libuchardet.so.* libonig.so.* Plugins/NetRocks/plug/libnfs.so.* Plugins/NetRocks/plug/libssh.so.* Plugins/NetRocks/plug/libneon.so.* Plugins/NetRocks/plug/libssl.so.* Plugins/NetRocks/plug/libcrypto.so.* >/dev/null
zip --symlinks -r "$current_path/far2m-bin-$FAR2M_DATE-$FAR2M_COMMIT-$MACHINE-$LIBC-$CODENAME.zip" . >/dev/null
cd $current_path
