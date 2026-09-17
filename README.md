# LuaJIT Precompiler

This repository precompiles upstream LuaJIT for a range of target platforms.

## Prerequisites

The build host must provide:

- A POSIX shell, GNU Make, Ninja, a native GCC toolchain, and the standard file utilities: `cp`, `find`, `mkdir`, `tar`, `sha256sum`, `awk`, `wc`, `tr`, `date`, `sort`, and `grep`.
- Git when `LUAJIT_DIR` is a Git worktree. A non-Git source directory is copied with `cp` instead.
- `LUAJIT_DIR`, set to an existing upstream LuaJIT source tree containing `Makefile` and `src/Makefile`. The build reads that tree and copies it into isolated target workspaces; it never compiles or modifies files in `LUAJIT_DIR`.

To build every Linux and Windows target, install these cross-toolchains. Each must include its matching `gcc`, `ar`, `ranlib`, and `strip` programs:

- `i686-linux-gnu-`
- `aarch64-linux-gnu-`
- `arm-linux-gnueabi-`
- `arm-linux-gnueabihf-`
- `mips-linux-gnu-`
- `mipsel-linux-gnu-`
- `mips64el-linux-gnuabi64-`
- `x86_64-w64-mingw32-`
- `i686-w64-mingw32-`

On Debian-based hosts, the corresponding compiler packages are `gcc-i686-linux-gnu`, `gcc-aarch64-linux-gnu`, `gcc-arm-linux-gnueabi`, `gcc-arm-linux-gnueabihf`, `gcc-mips-linux-gnu`, `gcc-mipsel-linux-gnu`, `gcc-mips64el-linux-gnuabi64`, `gcc-mingw-w64-x86-64`, and `gcc-mingw-w64-i686`.

Android builds require Android NDK `27.2.12479018`, including its LLVM toolchain for Linux hosts. Set `ANDROID_NDK_ROOT` to that NDK, or set `ANDROID_HOME` so the default resolves to `ANDROID_HOME/ndk/27.2.12479018`.

macOS and iOS builds require an osxcross installation with the relevant macOS, iPhoneOS, and iPhoneSimulator SDKs. Set `OSXCROSS_ROOT` to its target directory, or install it at the default `XDG_DATA_HOME/osxcross/target` path. The installation must provide `o64-clang`, `oa64-clang`, `iossimx64-clang`, `ios64-clang`, `iossim64-clang`, `x86_64-apple-darwin25.1-ar`, `aarch64-apple-darwin25.1-ar`, and `ios-ar` under `bin/`.

## Build

Run `make all` to build every supported target, or use an individual target such as `make x86_64/linux`.

Supported targets are:

- `x86_64/linux`, `x86_64/windows`, `x86_64/macos`, `x86_64/iossim`
- `i686/linux`, `i686/windows`
- `aarch64/linux`, `aarch64/android`, `aarch64/macos`, `aarch64/ios`, `aarch64/iossim`
- `armv7/linux`, `armv7/android`, `armv7hf/linux`
- `mips/linux`, `mipsel/linux`, `mips64el/linux`

## Outputs

Each build uses `.build/<arch>/<platform>/source/` as an isolated LuaJIT source workspace. `.build/` is ephemeral and can be deleted safely.

Published runtime files are written to `dist/<arch>/<platform>/`. Every target includes its LuaJIT executable, runtime shared library where LuaJIT requires one, and the `jit/` Lua modules. `dist/` is fully regenerable and can be deleted safely.

`dist/manifest.json` is generated from the files that are actually staged. `dist/SHA256SUMS` contains SHA-256 entries for every published target file, using paths relative to `dist/`.
