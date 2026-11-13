#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/sync-harness

# Kompiliert den echten Apple-Sync-Code (LocalSync + echte Stores) als CLI.
# Haptik/Ton werden durch No-Ops ersetzt; das Wire-Format bleibt unverändert.
swiftc -swift-version 5 -O \
  -framework Network \
  -framework Combine \
  -framework WidgetKit \
  -framework SwiftUI \
  Toolbox/LocalSync.swift \
  Toolbox/WaterStore.swift \
  Toolbox/SmartCalc/Counter/CounterStore.swift \
  swift-sync-harness/Support.swift \
  swift-sync-harness/main.swift \
  -o build/sync-harness/toolbox-sync-harness
