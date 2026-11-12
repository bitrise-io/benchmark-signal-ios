#!/usr/bin/env bash
# Not timed. Same as the Bitrise "Prepare dependencies" step.
set -eo pipefail
cd "$GITHUB_WORKSPACE"
Scripts/check_xcode_version.py --relaxed || echo "⚠️ Xcode version differs from .xcode-version"
git submodule update --init --recursive
make fetch-ringrtc
xcodebuild -downloadComponent MetalToolchain || true
xcodebuild -resolvePackageDependencies -workspace Signal.xcworkspace -scheme "$SIGNAL_SCHEME" -clonedSourcePackagesDirPath "$SPM_DIR"
defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES
