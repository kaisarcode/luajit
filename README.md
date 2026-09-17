# LuaJIT Runtime Distribution

This repository precompiles LuaJIT for a wide range of targets.

## Prerequisite

Set `LUAJIT_DIR` to an existing LuaJIT source checkout. The build only reads that checkout and copies it into isolated target workspaces; it never compiles or modifies files in `LUAJIT_DIR`.

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
