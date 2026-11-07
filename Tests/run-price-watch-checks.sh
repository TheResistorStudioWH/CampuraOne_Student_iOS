#!/bin/sh
set -eu
CAMPURA_PRICE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CAMPURA_PRICE_TEMP=$(mktemp -d /private/tmp/campura-price-checks.XXXXXX)
trap 'rm -rf "$CAMPURA_PRICE_TEMP"' EXIT HUP INT TERM
cd "$CAMPURA_PRICE_ROOT"
swiftc -parse-as-library -module-cache-path "$CAMPURA_PRICE_TEMP/cache" \
  CampuraOne/DataStructure/PriceWatch/PriceWatchModels.swift \
  CampuraOne/ViewModels/PriceWatch/PriceWatchStore.swift Tests/PriceWatchChecks.swift \
  -o "$CAMPURA_PRICE_TEMP/checks"
"$CAMPURA_PRICE_TEMP/checks"
