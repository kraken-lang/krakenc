#!/usr/bin/env bash
# vendor-clang.sh - copy a minimal clang toolchain into tools/llvm/
#
# POSIX (Linux + macOS) counterpart to vendor-clang.ps1. Pulls clang + lld
# (Linux only - macOS uses the system ld64) + the lib/clang/<v>/include
# headers from a system LLVM install into tools/llvm/, so krakenc can
# eventually invoke a self-contained toolchain without the user having
# clang on PATH.
#
# Usage:   tools/vendor-clang.sh
#          tools/vendor-clang.sh --source /opt/homebrew/opt/llvm
#          tools/vendor-clang.sh --force
#
# tools/llvm/ is gitignored - each contributor runs this once locally.

set -euo pipefail

# -------- arg parsing --------
SOURCE=""
FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source) SOURCE="$2"; shift 2 ;;
        --force)  FORCE=1; shift ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

# -------- paths --------
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(dirname "$script_dir")"
dest="$project_root/tools/llvm"

# -------- detect OS --------
uname_s="$(uname -s)"
case "$uname_s" in
    Linux)  os=linux ;;
    Darwin) os=macos ;;
    *) echo "unsupported OS: $uname_s (use vendor-clang.ps1 on Windows)" >&2; exit 1 ;;
esac

# -------- find a system LLVM install --------
if [[ -z "$SOURCE" ]]; then
    candidates=()
    if [[ "$os" == "macos" ]]; then
        candidates+=(
            "/opt/homebrew/opt/llvm"     # Homebrew on Apple Silicon
            "/usr/local/opt/llvm"        # Homebrew on Intel
            "/opt/homebrew/opt/llvm@18"
            "/usr/local/opt/llvm@18"
        )
    else
        # Linux: prefer newest version dir under /usr/lib
        candidates+=(
            "/usr/lib/llvm-18"
            "/usr/lib/llvm-17"
            "/usr/lib/llvm-16"
            "/usr/local/llvm"
        )
    fi
    for c in "${candidates[@]}"; do
        if [[ -x "$c/bin/clang" ]]; then
            SOURCE="$c"
            break
        fi
    done
    # Last resort: derive from `which clang`
    if [[ -z "$SOURCE" ]] && command -v clang >/dev/null 2>&1; then
        clang_path="$(command -v clang)"
        # follow symlink, then go up two levels (bin/clang -> install root)
        clang_real="$(readlink -f "$clang_path" 2>/dev/null || echo "$clang_path")"
        SOURCE="$(dirname "$(dirname "$clang_real")")"
    fi
fi

if [[ -z "$SOURCE" ]] || [[ ! -d "$SOURCE" ]]; then
    echo "could not locate LLVM install. pass --source /path/to/llvm" >&2
    exit 1
fi

src_bin="$SOURCE/bin"
src_lib="$SOURCE/lib/clang"

for p in "$src_bin" "$src_lib"; do
    if [[ ! -d "$p" ]]; then
        echo "required path missing: $p" >&2
        exit 1
    fi
done

# -------- bail or wipe --------
if [[ -d "$dest" && "$FORCE" -eq 0 ]]; then
    echo "tools/llvm already exists. pass --force to overwrite."
    exit 0
fi
rm -rf "$dest"
mkdir -p "$dest/bin" "$dest/lib/clang"

echo "vendoring from: $SOURCE"
echo "           to: $dest"

# -------- per-OS essentials --------
# Linux: clang + ld.lld
# macOS: clang only (system ld64 is used; no lld bundled)
exes=(clang)
if [[ "$os" == "linux" ]]; then
    exes+=(ld.lld lld)
fi

for exe in "${exes[@]}"; do
    src="$src_bin/$exe"
    if [[ ! -f "$src" ]]; then
        echo "WARN skipping missing: $exe" >&2
        continue
    fi
    cp "$src" "$dest/bin/$exe"
    sz=$(stat -c%s "$dest/bin/$exe" 2>/dev/null || stat -f%z "$dest/bin/$exe")
    printf '  bin/%-20s %10d bytes\n' "$exe" "$sz"
done

# Resource headers (stddef.h, stdint.h, etc.) - one or more version dirs
for v in "$src_lib"/*; do
    [[ -d "$v" ]] || continue
    name="$(basename "$v")"
    cp -R "$v" "$dest/lib/clang/$name"
    sz=$(du -sk "$dest/lib/clang/$name" | cut -f1)
    printf '  lib/clang/%-15s %6d KB\n' "$name" "$sz"
done

# Ship the upstream LICENSE so redistribution is legal.
license_candidates=(
    "$SOURCE/LICENSE.TXT"
    "$SOURCE/share/doc/llvm/LICENSE.TXT"
    "$SOURCE/share/llvm/LICENSE.TXT"
)
for lc in "${license_candidates[@]}"; do
    if [[ -f "$lc" ]]; then
        cp "$lc" "$dest/LICENSE.TXT"
        echo "  LICENSE.TXT copied from $lc"
        break
    fi
done
if [[ ! -f "$dest/LICENSE.TXT" ]]; then
    echo "WARN no LICENSE.TXT found in $SOURCE - fetch one from the LLVM release before redistributing" >&2
fi

# Stamp version
ver="$("$dest/bin/clang" --version 2>&1 | head -n1)"
echo "$ver" > "$dest/VERSION.txt"

total=$(du -sm "$dest" | cut -f1)
echo
echo "Done. Total bundle: ${total} MB"
echo "Version: $ver"
