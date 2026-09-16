## Makefile
## Summary: Builds and publishes isolated LuaJIT runtime targets.
##
## Author: KaisarCode
## License: GNU GPL v3

LUAJIT_DIR ?=
ANDROID_HOME ?= $(HOME)/.local/share/android-sdk
ANDROID_NDK_ROOT ?= $(ANDROID_HOME)/ndk/27.2.12479018
XDG_DATA_HOME ?= $(HOME)/.local/share
OSXCROSS_ROOT ?= $(XDG_DATA_HOME)/osxcross/target
BUILD_DIR := .build
DIST_DIR := dist
comma := ,
TARGETS := \
    x86_64/linux x86_64/windows x86_64/macos x86_64/iossim \
    i686/linux i686/windows \
    aarch64/linux aarch64/android aarch64/macos aarch64/ios aarch64/iossim \
    armv7/linux armv7/android armv7hf/linux \
    mips/linux mipsel/linux mips64el/linux

.DEFAULT_GOAL := x86_64/linux
.PHONY: all dist $(TARGETS) \
    x86_64/macos-build aarch64/macos-build \
    x86_64/iossim-build aarch64/ios-build aarch64/iossim-build

define build_target
	@set -eu; \
	arch='$(1)'; \
	platform='$(2)'; \
	workspace='$(BUILD_DIR)/$(1)/$(2)'; \
	source='$(CURDIR)/$(BUILD_DIR)/$(1)/$(2)/luajit'; \
	destination='$(DIST_DIR)/$(1)/$(2)'; \
	if [ -z '$(LUAJIT_DIR)' ] || [ ! -f '$(LUAJIT_DIR)/Makefile' ] || [ ! -f '$(LUAJIT_DIR)/src/Makefile' ]; then \
		echo 'LUAJIT_DIR must name an upstream LuaJIT source tree' >&2; exit 1; \
	fi; \
	if [ ! -d "$$source" ]; then \
		mkdir -p "$$source"; \
		if git -C '$(LUAJIT_DIR)' rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
			git -C '$(LUAJIT_DIR)' archive --format=tar HEAD | tar -xf - -C "$$source"; \
		else \
			cp -a '$(LUAJIT_DIR)/.' "$$source"; \
		fi; \
	fi; \
	printf 'int main(void) { return 0; }\n' | $(3) -x c - -o "$$workspace/host-tool-probe" >/dev/null 2>&1 || { echo "$$arch/$$platform requires a usable host compiler: $(3)" >&2; exit 1; }; \
	command -v ninja >/dev/null 2>&1 || { echo 'missing required command: ninja' >&2; exit 1; }; \
	{ \
		printf '%s\n' 'rule luajit'; \
		printf '  command = %s\n' "$(MAKE) --no-print-directory -C $$source HOST_CC='$(3)' $(4) && touch \$$out"; \
		printf '  description = LuaJIT %s/%s\n' "$$arch" "$$platform"; \
		printf '%s\n' 'build luajit.stamp: luajit'; \
		printf '%s\n' 'default luajit.stamp'; \
	} > "$$workspace/build.ninja"; \
	(cd "$$workspace" && ninja); \
	mkdir -p "$$destination/jit"; \
	executable=luajit; if [ "$$platform" = windows ]; then executable=luajit.exe; fi; \
	[ -f "$$source/src/$$executable" ] || { echo "missing LuaJIT executable for $$arch/$$platform" >&2; exit 1; }; \
	cp -a "$$source/src/$$executable" "$$destination/$$executable"; \
	find "$$source/src" -maxdepth 1 \( -type f -o -type l \) \( -name 'libluajit-5.1.so*' -o -name 'libluajit-5.1.*.dylib' -o -name 'lua51.dll' \) -exec cp -L {} "$$destination/" \;; \
	find "$$source/src/jit" -maxdepth 1 -type f -name '*.lua' -exec cp -a {} "$$destination/jit/" \;; \
	printf 'OK %s/%s\n' "$$arch" "$$platform"
endef

define with_target_args
	$(call build_target,$(1),$(2),$(3),$(4))
	@$(MAKE) --no-print-directory dist
endef

all: $(TARGETS)
	@$(MAKE) --no-print-directory dist

x86_64/linux:
	$(call with_target_args,x86_64,linux,gcc,TARGET_SYS=Linux CROSS=)

i686/linux:
	$(call with_target_args,i686,linux,i686-linux-gnu-gcc -static,TARGET_SYS=Linux CROSS=i686-linux-gnu-)

aarch64/linux:
	$(call with_target_args,aarch64,linux,gcc,TARGET_SYS=Linux CROSS=aarch64-linux-gnu-)

armv7/linux:
	$(call with_target_args,armv7,linux,i686-linux-gnu-gcc -static,TARGET_SYS=Linux CROSS=arm-linux-gnueabi- TARGET_CFLAGS='-mfloat-abi=soft')

armv7hf/linux:
	$(call with_target_args,armv7hf,linux,i686-linux-gnu-gcc -static,TARGET_SYS=Linux CROSS=arm-linux-gnueabihf-)

mips/linux:
	$(call with_target_args,mips,linux,i686-linux-gnu-gcc -static,TARGET_SYS=Linux CROSS=mips-linux-gnu-)

mipsel/linux:
	$(call with_target_args,mipsel,linux,i686-linux-gnu-gcc -static,TARGET_SYS=Linux CROSS=mipsel-linux-gnu-)

mips64el/linux:
	$(call with_target_args,mips64el,linux,gcc,TARGET_SYS=Linux CROSS=mips64el-linux-gnuabi64- TARGET_CFLAGS='-mips64r2 -mabi=64')

x86_64/windows:
	$(call with_target_args,x86_64,windows,gcc,TARGET_SYS=Windows CROSS=x86_64-w64-mingw32-)

i686/windows:
	$(call with_target_args,i686,windows,i686-linux-gnu-gcc -static,TARGET_SYS=Windows CROSS=i686-w64-mingw32-)

aarch64/android:
	$(call with_target_args,aarch64,android,gcc,TARGET_SYS=Linux CROSS=$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android- STATIC_CC=$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang DYNAMIC_CC='$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang -fPIC' TARGET_LD=$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang TARGET_AR='$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcus' TARGET_STRIP=$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip)

armv7/android:
	$(call with_target_args,armv7,android,i686-linux-gnu-gcc -static,TARGET_SYS=Linux CROSS=$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/arm-linux-androideabi- STATIC_CC=$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang DYNAMIC_CC='$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang -fPIC' TARGET_LD=$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang TARGET_AR='$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcus' TARGET_STRIP=$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip)

x86_64/macos:
	@set -eu; \
	compiler='$(OSXCROSS_ROOT)/bin/o64-clang'; sdk='$(lastword $(sort $(wildcard $(OSXCROSS_ROOT)/SDK/MacOSX*.sdk)))'; \
	[ -x "$$compiler" ] && [ -d "$$sdk" ] || { echo 'missing macOS osxcross compiler or SDK' >&2; exit 1; }; \
	OSXCROSS_HOST=x86_64-apple-darwin25.1 OSXCROSS_TARGET_DIR='$(OSXCROSS_ROOT)' OSXCROSS_TARGET=darwin25.1 OSXCROSS_SDK="$$sdk" LD_LIBRARY_PATH='$(OSXCROSS_ROOT)/lib'"$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}" PATH='$(OSXCROSS_ROOT)/bin':"$$PATH" $(MAKE) --no-print-directory LUAJIT_DIR='$(LUAJIT_DIR)' x86_64/macos-build

x86_64/macos-build:
	$(call with_target_args,x86_64,macos,gcc,BUILDMODE=dynamic TARGET_SYS=Darwin CC=$(OSXCROSS_ROOT)/bin/o64-clang TARGET_CC=$(OSXCROSS_ROOT)/bin/o64-clang TARGET_LD=$(OSXCROSS_ROOT)/bin/o64-clang TARGET_AR='$(OSXCROSS_ROOT)/bin/x86_64-apple-darwin25.1-ar rcus' TARGET_STRIP=true TARGET_FLAGS='-arch x86_64' TARGET_LIBPATH=@loader_path TARGET_LDFLAGS='-Wl$(comma)-rpath$(comma)@loader_path' LUAJIT_SO=libluajit-5.1.2.dylib)

aarch64/macos:
	@set -eu; \
	compiler='$(OSXCROSS_ROOT)/bin/oa64-clang'; sdk='$(lastword $(sort $(wildcard $(OSXCROSS_ROOT)/SDK/MacOSX*.sdk)))'; \
	[ -x "$$compiler" ] && [ -d "$$sdk" ] || { echo 'missing macOS osxcross compiler or SDK' >&2; exit 1; }; \
	OSXCROSS_HOST=aarch64-apple-darwin25.1 OSXCROSS_TARGET_DIR='$(OSXCROSS_ROOT)' OSXCROSS_TARGET=darwin25.1 OSXCROSS_SDK="$$sdk" LD_LIBRARY_PATH='$(OSXCROSS_ROOT)/lib'"$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}" PATH='$(OSXCROSS_ROOT)/bin':"$$PATH" $(MAKE) --no-print-directory LUAJIT_DIR='$(LUAJIT_DIR)' aarch64/macos-build

aarch64/macos-build:
	$(call with_target_args,aarch64,macos,gcc,BUILDMODE=dynamic TARGET_SYS=Darwin CC=$(OSXCROSS_ROOT)/bin/oa64-clang TARGET_CC=$(OSXCROSS_ROOT)/bin/oa64-clang TARGET_LD=$(OSXCROSS_ROOT)/bin/oa64-clang TARGET_AR='$(OSXCROSS_ROOT)/bin/aarch64-apple-darwin25.1-ar rcus' TARGET_STRIP=true TARGET_FLAGS='-arch arm64' TARGET_LIBPATH=@loader_path TARGET_LDFLAGS='-Wl$(comma)-rpath$(comma)@loader_path' LUAJIT_SO=libluajit-5.1.2.dylib)

x86_64/iossim:
	@set -eu; \
	compiler='$(OSXCROSS_ROOT)/bin/iossimx64-clang'; sdk='$(lastword $(sort $(wildcard $(OSXCROSS_ROOT)/SDK/iPhoneSimulator*.sdk)))'; \
	[ -x "$$compiler" ] && [ -d "$$sdk" ] || { echo 'missing iOS simulator osxcross compiler or SDK' >&2; exit 1; }; \
	OSXCROSS_HOST=x86_64-apple-darwin25.1 OSXCROSS_TARGET_DIR='$(OSXCROSS_ROOT)' OSXCROSS_TARGET=darwin25.1 OSXCROSS_SDK="$$sdk" LD_LIBRARY_PATH='$(OSXCROSS_ROOT)/lib'"$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}" PATH='$(OSXCROSS_ROOT)/bin':"$$PATH" $(MAKE) --no-print-directory LUAJIT_DIR='$(LUAJIT_DIR)' x86_64/iossim-build

x86_64/iossim-build:
	$(call with_target_args,x86_64,iossim,gcc,BUILDMODE=dynamic TARGET_SYS=iOS CC=$(OSXCROSS_ROOT)/bin/iossimx64-clang TARGET_CC=$(OSXCROSS_ROOT)/bin/iossimx64-clang TARGET_LD=$(OSXCROSS_ROOT)/bin/iossimx64-clang TARGET_AR='$(OSXCROSS_ROOT)/bin/ios-ar rcus' TARGET_STRIP=true TARGET_FLAGS='-arch x86_64' TARGET_LIBPATH=@loader_path TARGET_LDFLAGS='-Wl$(comma)-rpath$(comma)@loader_path' LUAJIT_SO=libluajit-5.1.2.dylib)

aarch64/ios:
	@set -eu; \
	compiler='$(OSXCROSS_ROOT)/bin/ios64-clang'; sdk='$(lastword $(sort $(wildcard $(OSXCROSS_ROOT)/SDK/iPhoneOS*.sdk)))'; \
	[ -x "$$compiler" ] && [ -d "$$sdk" ] || { echo 'missing iOS osxcross compiler or SDK' >&2; exit 1; }; \
	OSXCROSS_HOST=aarch64-apple-darwin25.1 OSXCROSS_TARGET_DIR='$(OSXCROSS_ROOT)' OSXCROSS_TARGET=darwin25.1 OSXCROSS_SDK="$$sdk" LD_LIBRARY_PATH='$(OSXCROSS_ROOT)/lib'"$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}" PATH='$(OSXCROSS_ROOT)/bin':"$$PATH" $(MAKE) --no-print-directory LUAJIT_DIR='$(LUAJIT_DIR)' aarch64/ios-build

aarch64/ios-build:
	$(call with_target_args,aarch64,ios,gcc,BUILDMODE=dynamic TARGET_SYS=iOS CC=$(OSXCROSS_ROOT)/bin/ios64-clang TARGET_CC=$(OSXCROSS_ROOT)/bin/ios64-clang TARGET_LD=$(OSXCROSS_ROOT)/bin/ios64-clang TARGET_AR='$(OSXCROSS_ROOT)/bin/ios-ar rcus' TARGET_STRIP=true TARGET_FLAGS='-arch arm64' TARGET_LIBPATH=@loader_path TARGET_LDFLAGS='-Wl$(comma)-rpath$(comma)@loader_path' LUAJIT_SO=libluajit-5.1.2.dylib)

aarch64/iossim:
	@set -eu; \
	compiler='$(OSXCROSS_ROOT)/bin/iossim64-clang'; sdk='$(lastword $(sort $(wildcard $(OSXCROSS_ROOT)/SDK/iPhoneSimulator*.sdk)))'; \
	[ -x "$$compiler" ] && [ -d "$$sdk" ] || { echo 'missing iOS simulator osxcross compiler or SDK' >&2; exit 1; }; \
	OSXCROSS_HOST=aarch64-apple-darwin25.1 OSXCROSS_TARGET_DIR='$(OSXCROSS_ROOT)' OSXCROSS_TARGET=darwin25.1 OSXCROSS_SDK="$$sdk" LD_LIBRARY_PATH='$(OSXCROSS_ROOT)/lib'"$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}" PATH='$(OSXCROSS_ROOT)/bin':"$$PATH" $(MAKE) --no-print-directory LUAJIT_DIR='$(LUAJIT_DIR)' aarch64/iossim-build

aarch64/iossim-build:
	$(call with_target_args,aarch64,iossim,gcc,BUILDMODE=dynamic TARGET_SYS=iOS CC=$(OSXCROSS_ROOT)/bin/iossim64-clang TARGET_CC=$(OSXCROSS_ROOT)/bin/iossim64-clang TARGET_LD=$(OSXCROSS_ROOT)/bin/iossim64-clang TARGET_AR='$(OSXCROSS_ROOT)/bin/ios-ar rcus' TARGET_STRIP=true TARGET_FLAGS='-arch arm64' TARGET_LIBPATH=@loader_path TARGET_LDFLAGS='-Wl$(comma)-rpath$(comma)@loader_path' LUAJIT_SO=libluajit-5.1.2.dylib)

dist:
	@set -eu; \
	mkdir -p '$(DIST_DIR)'; \
	(cd '$(DIST_DIR)' && find . -type f ! -name SHA256SUMS ! -name manifest.json -printf '%P\n' | LC_ALL=C sort | while IFS= read -r file; do sha256sum "$$file"; done) > '$(DIST_DIR)/SHA256SUMS'; \
	{ \
		printf '{\n    "updated_at": "%s",\n    "timestamp": %s,\n    "targets": [\n' "$$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$$(date -u +%s)"; \
		first_target=1; \
		find '$(DIST_DIR)' -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | LC_ALL=C sort | while IFS=/ read -r arch platform; do \
			files=$$(find '$(DIST_DIR)'/"$$arch"/"$$platform" -type f -printf '%P\n' | LC_ALL=C sort); [ -n "$$files" ] || continue; \
			if [ "$$first_target" -eq 0 ]; then printf ',\n'; fi; first_target=0; \
			printf '        {\n            "arch": "%s",\n            "platform": "%s",\n            "files": [\n' "$$arch" "$$platform"; \
			first_file=1; printf '%s\n' "$$files" | while IFS= read -r file; do \
				path="$$arch/$$platform/$$file"; checksum=$$(awk -v path="$$path" '$$2 == path { print $$1 }' '$(DIST_DIR)/SHA256SUMS'); size=$$(wc -c < '$(DIST_DIR)'/"$$path" | tr -d ' '); \
				if [ "$$first_file" -eq 0 ]; then printf ',\n'; fi; first_file=0; \
				printf '                {"path": "%s", "size_bytes": %s, "sha256": "%s"}' "$$path" "$$size" "$$checksum"; \
			done; printf '\n            ]\n        }'; \
		done; \
		printf '\n    ]\n}\n'; \
	} > '$(DIST_DIR)/manifest.json'; \
	(cd '$(DIST_DIR)' && sha256sum --check SHA256SUMS >/dev/null); \
	find '$(DIST_DIR)' -mindepth 3 -maxdepth 3 -type f \( -name luajit -o -name luajit.exe \) | grep -q . || { echo 'no LuaJIT executables were staged' >&2; exit 1; }
