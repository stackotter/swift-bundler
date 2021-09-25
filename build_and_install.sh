#!/bin/sh
swift build -c release
cp .build/release/swift-bundler /usr/local/bin/
