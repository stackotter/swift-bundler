#!/bin/zsh

# This script generates a JSON schema file (Bundler.schema.json) which describes the schema of
# Swift Bundler's Bundler.toml configuration file format.
#
# Usage:
#   ./generate_schema.sh
#   ./generate_schema.sh stdout

CONFIG_SRC_DIR="Sources/swift-bundler/Configuration"
OUT="$(swift run schema-gen $CONFIG_SRC_DIR)"

if [ "$1" = "stdout" ]
then
  echo $OUT
else
  echo $OUT > Bundler.schema.json
fi
