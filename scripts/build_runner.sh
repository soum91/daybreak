#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || brew install xcodegen
(cd Runner && xcodegen generate)
xcodebuild build-for-testing -project Runner/DaybreakRunner.xcodeproj -scheme DaybreakRunner \
  -destination 'generic/platform=iOS' -derivedDataPath build/runner-device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= \
  MARKETING_VERSION="0.1.${BUILD_NUMBER:-1}" CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" > build/runner-build.log 2>&1 || { tail -150 build/runner-build.log; exit 1; }
python3 scripts/package_runner.py
