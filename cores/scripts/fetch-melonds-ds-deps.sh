#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THIRD_PARTY_DIR="${THIRD_PARTY_DIR:-$ROOT_DIR/third_party}"

mkdir -p "$THIRD_PARTY_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required" >&2
  exit 1
fi

clone_or_update() {
  local name="$1"
  local repo="$2"
  local ref="$3"
  local dest="$THIRD_PARTY_DIR/$name"

  echo ""
  echo "==> $name"
  if [ -d "$dest/.git" ]; then
    echo "Using existing repo: $dest"
    git -C "$dest" fetch --tags --prune origin
  elif [ -d "$dest" ]; then
    echo "ERROR: $dest exists but is not a git repo. Move/remove it and rerun." >&2
    exit 1
  else
    git clone "$repo" "$dest"
  fi

  git -C "$dest" checkout "$ref"
}

# Versions pinned to melonds-ds/cmake/FetchDependencies.cmake in your local checkout.
clone_or_update "melonDS-jesseTG" "https://github.com/JesseTG/melonDS" "f6692df"
clone_or_update "libretro-common" "https://github.com/JesseTG/libretro-common" "8e2b884"
clone_or_update "embed-binaries" "https://github.com/andoalon/embed-binaries.git" "21f28ca"
clone_or_update "glm" "https://github.com/g-truc/glm" "33b4a62"
clone_or_update "libslirp-mirror" "https://github.com/JesseTG/libslirp-mirror" "e61dbd4"
clone_or_update "pntr" "https://github.com/robloach/pntr" "650237a"
clone_or_update "fmt" "https://github.com/fmtlib/fmt" "11.0.2"
clone_or_update "yamc" "https://github.com/yohhoy/yamc" "4e015a7"
clone_or_update "span-lite" "https://github.com/martinmoene/span-lite" "00afc28"
clone_or_update "date" "https://github.com/HowardHinnant/date" "1ead671"
clone_or_update "zlib" "https://github.com/madler/zlib" "v1.3.1"

echo ""
echo "Done. Next:"
echo "  bash \"$ROOT_DIR/scripts/build-melonds-ds-libretro-static.sh\""
echo ""
echo "Note: melonds-ds expects the JesseTG melonDS fork. It is cloned to:"
echo "  $THIRD_PARTY_DIR/melonDS-jesseTG"
