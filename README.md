# Portable far2m build script

Script for building portable version of [far2m](https://github.com/shmuz/far2m).

Binaries are built within Ubuntu.

Install dependencies: `cmake g++ libarchive-dev libluajit-5.1-dev libneon27-dev libnfs-dev libonig-dev libsmbclient-dev libsqlite3-dev libssh-dev libuchardet-dev libwxgtk3.0-gtk3-dev luarocks make patchelf pkg-config unzip uuid-dev zip`.

Install oniguruma (for Highlight plugin): `luarocks install lrexlib-oniguruma --lua-version 5.1`.

Download [far2m](https://github.com/shmuz/far2m) and [luafar2m](https://github.com/shmuz/luafar2m) sources, review and run `build_far2m.sh`.
