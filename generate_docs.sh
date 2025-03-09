#!/usr/bin/env bash

set -xe

rm -rdf ../swift-docc-render-artifact
mkdir -p gh-pages/docs

export DOCC_JSON_PRETTYPRINT="YES"
export SWIFTPM_ENABLE_COMMAND_PLUGINS=1
git clone --depth=1 https://github.com/stackotter/swift-docc-render-artifact ../swift-docc-render-artifact
export DOCC_HTML_DIR=../swift-docc-render-artifact/dist

swift package \
  --allow-writing-to-directory gh-pages/docs \
  generate-documentation \
  --target SwiftBundler \
  --disable-indexing \
  --transform-for-static-hosting \
  --output-path gh-pages/docs
