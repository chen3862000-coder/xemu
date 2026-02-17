#!/usr/bin/env bash
set -euo pipefail

echo "Installing Homebrew bundle dependencies..."
brew bundle --quiet

echo "Installing CocoaPods dependencies..."
if [ -f "ios/AppHost/Podfile" ]; then
  (cd ios/AppHost && pod install >/dev/null)
else
  echo "Podfile not found; skipping pod install"
fi

echo "Resolving Swift package dependencies..."
if [ -f "ios/AppHost/Package.swift" ]; then
  (cd ios/AppHost && swift package resolve >/dev/null)
fi

echo "Bootstrap complete."
