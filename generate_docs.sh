#!/usr/bin/env bash

set -xe

export DOCC_JSON_PRETTYPRINT="YES"

mkdir -p docs

swift package \
  --allow-writing-to-directory docs \
  generate-documentation \
  --target swift-bundler \
  --transform-for-static-hosting \
  --output-path docs

# Patch target name from swift_bundler to swift-bundler
mv docs/documentation/swift_bundler/index.html docs/documentation/swift-bundler
mv docs/data/documentation/swift_bundler.json docs/data/documentation/swift-bundler.json
case $(uname -s) in
  Linux*) LC_ALL=C find docs -type f -exec sed -i 's/swift_bundler/swift-bundler/g' {} \;;;
  Darwin*) LC_ALL=C find docs -type f -exec sed -i '' -e 's/swift_bundler/swift-bundler/g' {} \;;;
esac
