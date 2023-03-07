#!/bin/zsh

# This script generates a JSON schema file (Bundler.schem.json) which describes the schema of
# Swift Bundler's Bundler.toml configuration file format.

PACKAGE_CONFIG_SRC_FILE="Sources/swift-bundler/Configuration/PackageConfiguration.swift"
APP_CONFIG_SRC_FILE="Sources/swift-bundler/Configuration/AppConfiguration.swift"
PLIST_VALUE_SRC_FILE="Sources/swift-bundler/Configuration/PlistValue.swift"

swift run schema-gen $PACKAGE_CONFIG_SRC_FILE $APP_CONFIG_SRC_FILE $PLIST_VALUE_SRC_FILE > Bundler.schema.json
