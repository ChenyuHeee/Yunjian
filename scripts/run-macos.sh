#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen 未安装。可用 Homebrew 安装："
  echo "  brew install xcodegen"
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild 不可用。请先安装 Xcode（并在首次启动后同意许可）。"
  exit 1
fi

xcodegen generate >/dev/null

DERIVED_DATA=".derivedData"
SCHEME="YunjianApp-macOS"
WORKSPACE="Yunjian.xcodeproj/project.xcworkspace"

if [[ ! -d "$WORKSPACE" ]]; then
  echo "未找到 Xcode workspace：$WORKSPACE"
  echo "请确认已在项目根目录执行，或先运行：xcodegen generate"
  exit 1
fi

xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug/$SCHEME.app"

if [[ ! -d "$APP_PATH" ]]; then
  CANDIDATE=$(find "$DERIVED_DATA/Build/Products/Debug" -maxdepth 1 -name "$SCHEME.app" -print -quit 2>/dev/null || true)
  if [[ -n "${CANDIDATE:-}" ]]; then
    APP_PATH="$CANDIDATE"
  else
    CANDIDATE=$(find "$DERIVED_DATA/Build/Products/Debug" -maxdepth 1 -name "*.app" -print -quit 2>/dev/null || true)
    if [[ -n "${CANDIDATE:-}" ]]; then
      APP_PATH="$CANDIDATE"
    fi
  fi
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "未找到产物：$APP_PATH"
  exit 1
fi

open "$APP_PATH"

echo "已启动：$APP_PATH"
