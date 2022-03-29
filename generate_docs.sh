#!/bin/sh

swift package \
  --allow-writing-to-directory docs \
  generate-documentation \
  --target swift-bundler \
  --disable-indexing \
  --transform-for-static-hosting \
  --hosting-base-path swift-bundler \
  --output-path docs \
  --experimental-documentation-coverage \
  --level brief
