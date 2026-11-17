#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/sync-harness

# Compiles the real Apple sync code (LocalSync + real stores) as a CLI.
# Haptics/sound are replaced by no-ops; the wire format stays unchanged.
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
