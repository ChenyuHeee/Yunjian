#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen 未安装。可用 Homebrew 安装："
  echo "  brew install xcodegen"
  exit 1
fi

xcodegen generate

echo "已生成 Xcode 工程：Yunjian.xcodeproj"
