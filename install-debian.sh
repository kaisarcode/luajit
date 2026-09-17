#!/bin/bash
# Install Debian Dependencies
# Summary: Install the Debian build dependencies for this repository.
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: GNU General Public License v3.0

set -Eeuo pipefail

NDK_VERSION="27.2.12479018"
NDK_RELEASE="r27c"
NDK_ARCHIVE="android-ndk-${NDK_RELEASE}-linux.zip"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ANDROID_HOME="${ANDROID_HOME:-$DATA_HOME/android-sdk}"
ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$ANDROID_HOME/ndk/$NDK_VERSION}"
OSXCROSS_ROOT="${OSXCROSS_ROOT:-$DATA_HOME/osxcross/target}"
OSXCROSS_SOURCE="${OSXCROSS_SOURCE:-$DATA_HOME/osxcross/src}"
OSXCROSS_TARBALLS="${OSXCROSS_TARBALLS:-$OSXCROSS_SOURCE/tarballs}"
OSXCROSS_SDK_ROOT="${OSXCROSS_SDK_ROOT:-$OSXCROSS_ROOT/SDK}"
OSXCROSS_REPOSITORY="${OSXCROSS_REPOSITORY:-https://github.com/tpoechtrager/osxcross}"
MACOS_SDK_RELEASE_API="${MACOS_SDK_RELEASE_API:-https://api.github.com/repos/joseluisq/macosx-sdks/releases/latest}"
IPHONEOS_SDK_RELEASE_APIS="${IPHONEOS_SDK_RELEASE_APIS:-https://api.github.com/repos/xybp888/iOS-SDKs/releases/latest https://api.github.com/repos/theos/sdks/releases/latest}"
IPHONESIMULATOR_SDK_RELEASE_APIS="${IPHONESIMULATOR_SDK_RELEASE_APIS:-https://api.github.com/repos/xybp888/iOS-SDKs/releases/latest}"
IPHONESIMULATOR_SDK_REPOSITORY="${IPHONESIMULATOR_SDK_REPOSITORY:-https://github.com/wimal-build/iPhoneSimulator.sdk.git}"
IPHONESIMULATOR_SDK_REF="${IPHONESIMULATOR_SDK_REF:-main}"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-13.0}"

# Print a progress message.
# @return 0 on success.
log() { printf '[INFO] %s\n' "$*"; }

# Print an error and stop the installer.
# @return Does not return.
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

# Run a command with root privileges.
# @return The command exit status.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Confirm that the host is Debian.
# @return 0 when the host is Debian.
require_debian() {
    [ -r /etc/os-release ] || fail '/etc/os-release not found.'
    . /etc/os-release
    [ "${ID:-}" = 'debian' ] || fail 'This installer supports Debian only.'
}

# Install the APT packages required by all targets.
# @return 0 on success.
install_packages() {
    local packages=(
        ca-certificates
        curl
        git
        make
        ninja-build
        tar
        unzip
        xz-utils
        bzip2
        zstd
        cpio
        patch
        pkg-config
        python3
        gcc
        clang
        llvm
        lld
        libssl-dev
        zlib1g-dev
        libxml2-dev
        libbz2-dev
        liblzma-dev
        libmpc-dev
        libmpfr-dev
        libgmp-dev
        uuid-dev
        gcc-i686-linux-gnu
        gcc-aarch64-linux-gnu
        gcc-arm-linux-gnueabi
        gcc-arm-linux-gnueabihf
        gcc-mips-linux-gnu
        gcc-mipsel-linux-gnu
        gcc-mips64el-linux-gnuabi64
        gcc-mingw-w64-x86-64
        gcc-mingw-w64-i686
    )

    log 'Installing Debian packages...'
    export DEBIAN_FRONTEND=noninteractive
    as_root apt-get update
    as_root apt-get install -y "${packages[@]}"
}

# Download the highest-versioned matching asset from one GitHub release API.
# @param $1 Release API URL.
# @param $2 Asset-name regular expression.
# @param $3 Destination directory.
# @return 0 with the downloaded archive path on stdout.
download_release_asset() {
    local release_api="$1"
    local asset_pattern="$2"
    local destination="$3"
    local release_json
    local metadata
    local asset_url
    local checksum_url
    local asset_path
    local checksum_path

    mkdir -p "$destination"
    release_json=$(mktemp)
    curl -fsSL "$release_api" -o "$release_json"
    metadata=$(python3 - "$release_json" "$asset_pattern" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    assets = json.load(source).get("assets", [])

pattern = re.compile(sys.argv[2])
matches = []
checksum = ""
for asset in assets:
    name = asset.get("name", "")
    url = asset.get("browser_download_url", "")
    if name in {"sha256sum.txt", "SHA256SUMS", "checksums.txt"}:
        checksum = url
    if pattern.match(name) and url:
        version = tuple(int(part) for part in re.findall(r"\d+", name))
        matches.append((version, url))

if not matches:
    raise SystemExit(1)

matches.sort()
print(matches[-1][1])
print(checksum)
PY
)
    rm -f "$release_json"
    asset_url=$(printf '%s\n' "$metadata" | sed -n '1p')
    checksum_url=$(printf '%s\n' "$metadata" | sed -n '2p')
    [ -n "$asset_url" ] || fail "No matching SDK asset in $release_api."
    asset_path="$destination/$(basename "$asset_url")"

    if [ ! -f "$asset_path" ]; then
        log "Downloading $(basename "$asset_path")..." >&2
        curl -fL "$asset_url" -o "$asset_path" >&2
    fi

    if [ -n "$checksum_url" ]; then
        checksum_path="$destination/$(basename "$checksum_url")"
        curl -fsSL "$checksum_url" -o "$checksum_path"
        (
            cd "$destination"
            sha256sum -c --ignore-missing "$(basename "$checksum_path")" >/dev/null
        ) || fail "Checksum verification failed for $(basename "$asset_path")."
    fi

    printf '%s\n' "$asset_path"
}

# Download a matching asset from the first release API that provides one.
# @param $1 Space-separated release API URLs.
# @param $2 Asset-name regular expression.
# @param $3 Destination directory.
# @return 0 with the downloaded archive path on stdout.
download_release_asset_from_apis() {
    local release_apis="$1"
    local asset_pattern="$2"
    local destination="$3"
    local -a release_api_list
    local release_api

    read -r -a release_api_list <<< "$release_apis"
    for release_api in "${release_api_list[@]}"; do
        if download_release_asset "$release_api" "$asset_pattern" "$destination"; then
            return 0
        fi
    done

    fail 'No configured release API provided the required SDK archive.'
}

# Return the newest installed SDK path for a prefix.
# @param $1 SDK directory prefix.
# @return 0 with the SDK path on stdout when found.
find_sdk() {
    local prefix="$1"

    find "$OSXCROSS_SDK_ROOT" -maxdepth 1 -type d -name "$prefix*.sdk" 2>/dev/null | sort -V | tail -n 1
}

# Install the Android NDK used by the Android targets.
# @return 0 on success.
install_ndk() {
    local temporary_directory

    if [ -x "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar" ]; then
        return 0
    fi

    log "Installing Android NDK $NDK_VERSION..."
    mkdir -p "$(dirname "$ANDROID_NDK_ROOT")"
    temporary_directory=$(mktemp -d)
    curl -fL "https://dl.google.com/android/repository/$NDK_ARCHIVE" -o "$temporary_directory/ndk.zip"
    unzip -q "$temporary_directory/ndk.zip" -d "$temporary_directory"
    mv "$temporary_directory/android-ndk-$NDK_RELEASE" "$ANDROID_NDK_ROOT"
    rm -rf "$temporary_directory"
}

# Install osxcross and a macOS SDK for the macOS targets.
# @return 0 on success.
install_osxcross() {
    local macos_sdk

    if [ -x "$OSXCROSS_ROOT/bin/o64-clang" ] && [ -x "$OSXCROSS_ROOT/bin/oa64-clang" ]; then
        return 0
    fi

    if [ ! -d "$OSXCROSS_SOURCE/.git" ]; then
        [ ! -e "$OSXCROSS_SOURCE" ] || fail "OSXCROSS_SOURCE exists but is not a Git checkout: $OSXCROSS_SOURCE"
        mkdir -p "$(dirname "$OSXCROSS_SOURCE")"
        git clone --depth 1 "$OSXCROSS_REPOSITORY" "$OSXCROSS_SOURCE"
    fi

    mkdir -p "$OSXCROSS_TARBALLS" "$(dirname "$OSXCROSS_ROOT")"
    macos_sdk=$(find "$OSXCROSS_TARBALLS" -maxdepth 1 -type f -name 'MacOSX*.sdk.tar*' -print -quit)
    if [ -z "$macos_sdk" ]; then
        download_release_asset "$MACOS_SDK_RELEASE_API" '^MacOSX[0-9.]+\.sdk\.tar(\..+)?$' "$OSXCROSS_TARBALLS" >/dev/null
    fi

    log 'Building osxcross...'
    (
        cd "$OSXCROSS_SOURCE"
        UNATTENDED=1 ENABLE_ARCHS='x86_64 arm64' TARGET_DIR="$OSXCROSS_ROOT" ./build.sh
    )
    [ -x "$OSXCROSS_ROOT/bin/o64-clang" ] || fail 'osxcross did not install o64-clang.'
    [ -x "$OSXCROSS_ROOT/bin/oa64-clang" ] || fail 'osxcross did not install oa64-clang.'
    find_sdk 'MacOSX' >/dev/null || fail 'osxcross did not install a macOS SDK.'
}

# Extract an SDK archive into the osxcross SDK directory.
# @param $1 Archive path.
# @return 0 on success.
extract_sdk() {
    local archive="$1"

    mkdir -p "$OSXCROSS_SDK_ROOT"
    case "$archive" in
        *.zip) unzip -q -o "$archive" -d "$OSXCROSS_SDK_ROOT" ;;
        *.tar|*.tar.*|*.tgz|*.txz) tar -xf "$archive" -C "$OSXCROSS_SDK_ROOT" ;;
        *) fail "Unsupported SDK archive: $archive" ;;
    esac
}

# Create a Clang wrapper for an iOS target.
# @param $1 Wrapper path.
# @param $2 Target triple prefix.
# @param $3 Target triple suffix.
# @param $4 Default SDK path.
# @return 0 on success.
write_ios_wrapper() {
    local wrapper="$1"
    local target_prefix="$2"
    local target_suffix="$3"
    local sdk_path="$4"

    printf '#!/bin/sh\n' > "$wrapper"
    printf 'exec clang -target %s${IOS_DEPLOYMENT_TARGET:-%s}%s -isysroot %s -fuse-ld=lld "$@"\n' \
        "$target_prefix" "$IOS_DEPLOYMENT_TARGET" "$target_suffix" "$sdk_path" >> "$wrapper"
    chmod +x "$wrapper"
}

# Install iPhoneOS and iPhoneSimulator SDKs and their compiler wrappers.
# @return 0 on success.
install_ios_tools() {
    local iphoneos_sdk
    local simulator_sdk
    local archive
    local temporary_directory

    iphoneos_sdk=$(find_sdk 'iPhoneOS' || true)
    if [ -z "$iphoneos_sdk" ]; then
        archive=$(download_release_asset_from_apis "$IPHONEOS_SDK_RELEASE_APIS" '^iPhoneOS[0-9.]+\.sdk\.(tar(\..+)?|zip)$' "$OSXCROSS_TARBALLS")
        extract_sdk "$archive"
        iphoneos_sdk=$(find_sdk 'iPhoneOS')
    fi

    simulator_sdk=$(find_sdk 'iPhoneSimulator' || true)
    if [ -z "$simulator_sdk" ]; then
        temporary_directory=$(mktemp -d)
        if git clone --depth 1 --branch "$IPHONESIMULATOR_SDK_REF" "$IPHONESIMULATOR_SDK_REPOSITORY" "$temporary_directory/sdk"; then
            mv "$temporary_directory/sdk" "$OSXCROSS_SDK_ROOT/iPhoneSimulator.sdk"
            rm -rf "$temporary_directory"
        else
            rm -rf "$temporary_directory"
            archive=$(download_release_asset_from_apis "$IPHONESIMULATOR_SDK_RELEASE_APIS" '^iPhoneSimulator[0-9.]+\.sdk\.(tar(\..+)?|zip)$' "$OSXCROSS_TARBALLS")
            extract_sdk "$archive"
        fi
        simulator_sdk=$(find_sdk 'iPhoneSimulator')
    fi

    [ -n "$iphoneos_sdk" ] || fail 'iPhoneOS SDK was not installed.'
    [ -n "$simulator_sdk" ] || fail 'iPhoneSimulator SDK was not installed.'
    mkdir -p "$OSXCROSS_ROOT/bin"
    write_ios_wrapper "$OSXCROSS_ROOT/bin/ios64-clang" 'arm64-apple-ios' '' "$iphoneos_sdk"
    write_ios_wrapper "$OSXCROSS_ROOT/bin/iossim64-clang" 'arm64-apple-ios' '-simulator' "$simulator_sdk"
    write_ios_wrapper "$OSXCROSS_ROOT/bin/iossimx64-clang" 'x86_64-apple-ios' '-simulator' "$simulator_sdk"
    printf '#!/bin/sh\nexec llvm-ar "$@"\n' > "$OSXCROSS_ROOT/bin/ios-ar"
    chmod +x "$OSXCROSS_ROOT/bin/ios-ar"
}

# Verify one GNU cross-toolchain used by the Makefile.
# @param $1 Toolchain command prefix.
# @return 0 on success.
verify_gnu_cross_toolchain() {
    local prefix="$1"
    local tool

    for tool in gcc ar ranlib strip; do
        command -v "$prefix$tool" >/dev/null || fail "Missing tool: $prefix$tool"
    done
}

# Verify that every compiler command used by the Makefile is available.
# @return 0 on success.
verify_toolchains() {
    local tool
    local tools=(
        gcc
        ninja
        "$OSXCROSS_ROOT/bin/o64-clang"
        "$OSXCROSS_ROOT/bin/oa64-clang"
        "$OSXCROSS_ROOT/bin/x86_64-apple-darwin25.1-ar"
        "$OSXCROSS_ROOT/bin/aarch64-apple-darwin25.1-ar"
        "$OSXCROSS_ROOT/bin/ios64-clang"
        "$OSXCROSS_ROOT/bin/iossim64-clang"
        "$OSXCROSS_ROOT/bin/iossimx64-clang"
        "$OSXCROSS_ROOT/bin/ios-ar"
        "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang"
        "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang"
        "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
        "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
    )

    for tool in "${tools[@]}"; do
        if [[ "$tool" == */* ]]; then
            [ -x "$tool" ] || fail "Missing tool: $tool"
        else
            command -v "$tool" >/dev/null || fail "Missing tool: $tool"
        fi
    done

    verify_gnu_cross_toolchain 'i686-linux-gnu-'
    verify_gnu_cross_toolchain 'aarch64-linux-gnu-'
    verify_gnu_cross_toolchain 'arm-linux-gnueabi-'
    verify_gnu_cross_toolchain 'arm-linux-gnueabihf-'
    verify_gnu_cross_toolchain 'mips-linux-gnu-'
    verify_gnu_cross_toolchain 'mipsel-linux-gnu-'
    verify_gnu_cross_toolchain 'mips64el-linux-gnuabi64-'
    verify_gnu_cross_toolchain 'x86_64-w64-mingw32-'
    verify_gnu_cross_toolchain 'i686-w64-mingw32-'
}

# Install all dependencies required by make all.
# @return 0 on success.
main() {
    require_debian
    install_packages
    install_ndk
    install_osxcross
    install_ios_tools
    verify_toolchains
    log 'LuaJIT build dependencies are ready.'
}

main "$@"
