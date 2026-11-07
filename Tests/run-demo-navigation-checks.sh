#!/bin/sh
set -eu
CAMPURA_IOS_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CAMAP_SWIFT_SOURCES=${CAMAP_SWIFT_SOURCES:-"$CAMPURA_IOS_ROOT/../../../Web-学校端/CampuraOne_Camap_SDK/swift/Sources/CamapKit"}
SWIFTY_JSON_SOURCE=${SWIFTY_JSON_SOURCE:-/private/tmp/CampuraOneDemoDerived/SourcePackages/checkouts/SwiftyJSON/Source/SwiftyJSON/SwiftyJSON.swift}
CAMPURA_CHECK_DIR=$(mktemp -d /private/tmp/campura-demo-navigation.XXXXXX)
trap 'rm -rf "$CAMPURA_CHECK_DIR"' EXIT HUP INT TERM
swiftc -parse-as-library -emit-library -emit-module -module-name CamapKit \
  -module-cache-path "$CAMPURA_CHECK_DIR/cache" "$CAMAP_SWIFT_SOURCES"/*.swift \
  -o "$CAMPURA_CHECK_DIR/libCamapKit.dylib" -emit-module-path "$CAMPURA_CHECK_DIR/CamapKit.swiftmodule"
swiftc -parse-as-library -emit-library -emit-module -module-name SwiftyJSON \
  -module-cache-path "$CAMPURA_CHECK_DIR/cache" "$SWIFTY_JSON_SOURCE" \
  -o "$CAMPURA_CHECK_DIR/libSwiftyJSON.dylib" -emit-module-path "$CAMPURA_CHECK_DIR/SwiftyJSON.swiftmodule"
cd "$CAMPURA_IOS_ROOT"
cp CampuraOne/OfflineResources/school-1-v2.camap "$CAMPURA_CHECK_DIR/"
swiftc -parse-as-library -D DEBUG -D DEMO -module-cache-path "$CAMPURA_CHECK_DIR/cache" \
  -I "$CAMPURA_CHECK_DIR" -L "$CAMPURA_CHECK_DIR" -lCamapKit -lSwiftyJSON \
  -Xlinker -rpath -Xlinker "$CAMPURA_CHECK_DIR" \
  CampuraOne/API/APIClientError.swift CampuraOne/API/APIDate.swift CampuraOne/API/APIConfig.swift \
  CampuraOne/DataStructure/Data-Navigation.swift CampuraOne/DataStructure/Data-Announce.swift \
  CampuraOne/DataStructure/Data-ContentPreview.swift CampuraOne/DataStructure/Data-Shop.swift \
  'CampuraOne/DataStructure/Data-ADs&Sales.swift' \
  'CampuraOne/Views/Map Layer/CampusMap/CampusMapGeometry.swift' \
  CampuraOne/ViewModels/Navigation/*.swift \
  CampuraOne/API/PreviewNavigation.swift Tests/DemoNavigationChecks.swift -o "$CAMPURA_CHECK_DIR/checks"
"$CAMPURA_CHECK_DIR/checks"
