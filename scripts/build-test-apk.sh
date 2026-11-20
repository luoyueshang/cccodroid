#!/bin/sh
# Build a separately installable test APK without using release signing material.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/.cccodroid/android-sdk}}
STATE=${CCCODROID_TEST_STATE:-$HOME/.cccodroid/test-build}
KEY=$STATE/signing.json

if [ -z "${ANDROID_JAR:-}" ] && [ -d "$SDK/platforms" ]; then
  PLATFORM=$(find "$SDK/platforms" -mindepth 1 -maxdepth 1 -type d -name 'android-*' | sort -V | tail -1)
  [ -z "$PLATFORM" ] || ANDROID_JAR=$PLATFORM/android.jar
fi
[ -n "${ANDROID_JAR:-}" ] && [ -f "$ANDROID_JAR" ] || {
  echo "✗ 找不到 android.jar；请先用 android-build 安装 Android SDK 平台，或设置 ANDROID_JAR" >&2
  exit 1
}

mkdir -p "$STATE"
chmod 700 "$STATE"
if [ ! -s "$KEY" ]; then
  command -v openssl >/dev/null 2>&1 || { echo "✗ 生成测试签名需要 openssl" >&2; exit 1; }
  TMP=$(mktemp -d "$STATE/key.XXXXXX")
  trap 'rm -rf "$TMP"' EXIT HUP INT TERM
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/key.pem" \
    -out "$TMP/cert.pem" -days 3650 -subj "/CN=cc.codtest local test/" >/dev/null 2>&1
  node -e 'const fs=require("fs");fs.writeFileSync(process.argv[1],JSON.stringify({key:fs.readFileSync(process.argv[2],"utf8"),cert:fs.readFileSync(process.argv[3],"utf8")}),{mode:0o600})' \
    "$KEY" "$TMP/key.pem" "$TMP/cert.pem"
  rm -rf "$TMP"
  trap - EXIT HUP INT TERM
fi
chmod 600 "$KEY"

ANDROID_JAR=$ANDROID_JAR KEY=$KEY OUT=${CCCODROID_TEST_OUT:-$ROOT/dist-test} \
APK_NAME=${CCCODROID_TEST_APK_NAME:-cccodroid-test.apk} \
  sh "$ROOT/scripts/build.sh"
