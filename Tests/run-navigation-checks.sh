#!/bin/sh
set -eu
CAMPURA_IOS_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CAMAP_SWIFT_SOURCES=${CAMAP_SWIFT_SOURCES:-"$CAMPURA_IOS_ROOT/../../../Web-学校端/CampuraOne_Camap_SDK/swift/Sources/CamapKit"}
CAMPURA_CHECK_DIR=$(mktemp -d /private/tmp/campura-navigation-checks.XXXXXX)
trap 'rm -rf "$CAMPURA_CHECK_DIR"' EXIT HUP INT TERM
swiftc -parse-as-library -emit-library -emit-module -module-name CamapKit \
  -module-cache-path "$CAMPURA_CHECK_DIR/cache" \
  "$CAMAP_SWIFT_SOURCES"/*.swift -o "$CAMPURA_CHECK_DIR/libCamapKit.dylib" \
  -emit-module-path "$CAMPURA_CHECK_DIR/CamapKit.swiftmodule"
cd "$CAMPURA_IOS_ROOT"
swiftc -parse-as-library -module-cache-path "$CAMPURA_CHECK_DIR/cache" \
  -I "$CAMPURA_CHECK_DIR" -L "$CAMPURA_CHECK_DIR" -lCamapKit \
  -Xlinker -rpath -Xlinker "$CAMPURA_CHECK_DIR" \
  CampuraOne/API/APIClientError.swift CampuraOne/API/APIDate.swift \
  CampuraOne/DataStructure/Data-Navigation.swift CampuraOne/DataStructure/Data-Announce.swift \
  'CampuraOne/Views/Map Layer/CampusMap/CampusMapGeometry.swift' \
  CampuraOne/ViewModels/Navigation/*.swift Tests/NavigationChecks.swift \
  -o "$CAMPURA_CHECK_DIR/checks"
"$CAMPURA_CHECK_DIR/checks" "$CAMPURA_IOS_ROOT/Tests/Fixtures/navigation-examples.json"
