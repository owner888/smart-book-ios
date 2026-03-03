#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GO_SRC_DIR="$RUNTIME_DIR/go-src"
OUT_DIR="$RUNTIME_DIR/artifacts"

if [[ ! -f "$GO_SRC_DIR/go.mod" ]]; then
  echo "go.mod not found in: $GO_SRC_DIR"
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "[1/3] tidying modules in $GO_SRC_DIR ..."
(
  cd "$GO_SRC_DIR"
  go mod tidy
)

echo "[2/3] building local c-archive ..."
(
  cd "$GO_SRC_DIR"

  IOS_SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
  IOS_CC="$(xcrun --sdk iphoneos --find clang)"

  export GOOS=ios
  export GOARCH=arm64
  export CGO_ENABLED=1
  export CC="$IOS_CC"
  export SDKROOT="$IOS_SDK_PATH"
  export CGO_CFLAGS="-isysroot $IOS_SDK_PATH -miphoneos-version-min=13.0"
  export CGO_LDFLAGS="-isysroot $IOS_SDK_PATH -miphoneos-version-min=13.0"

  go build -buildmode=c-archive -o "$OUT_DIR/libwidget_runtime_local.a" ./ffi/widget_runtime
)

echo "[3/3] syncing generated header to include ..."
cp "$OUT_DIR/libwidget_runtime_local.h" "$RUNTIME_DIR/include/widget_runtime.generated.h"

echo "done"
echo "archive:  $OUT_DIR/libwidget_runtime_local.a"
echo "header:   $OUT_DIR/libwidget_runtime_local.h"
echo "synced:   $RUNTIME_DIR/include/widget_runtime.generated.h"
