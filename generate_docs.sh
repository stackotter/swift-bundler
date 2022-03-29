#!/bin/sh

swift package \
  --allow-writing-to-directory docs \
  generate-documentation \
  --target swift-bundler \
  --disable-indexing \
  --transform-for-static-hosting \
  --hosting-base-path swift-bundler \
  --output-path docs \
  --enable-inherited-docs \
  --experimental-documentation-coverage \
  --level detailed \
#  --kinds enumeration \
#  --kinds structure \
#  --kinds type-method \
#  --kinds type-property \
#  --kinds instance-method \
#  --kinds instance-property \
#  --kinds instance-variable \
#  --kinds initializer 
#  --kinds global-variable \
#  --kinds enumeration-case \
#  --kinds module \
#  --kinds class \
#  --kinds structure \
#  --kinds enumeration \
#  --kinds protocol \
#  --kinds type-alias \
#  --kinds typedef \
#  --kinds associated-type \
#  --kinds "function" \
#  --kinds operator \
#  --kinds initializer \
#  --kinds instance-method \
#  --kinds instance-property \
#  --kinds instance-variable \
#  --kinds type-method \
#  --kinds type-property \
#  --kinds type-subscript \
