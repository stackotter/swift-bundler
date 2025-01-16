# Troubleshooting

Troubleshooting common issues.

## Overview

This article will act as a knowledge base of Swift Bundler troubleshooting
tips. Most tips relate to development environment or usage issues. Some
tips may be more general cross-platform Swift troubleshooting tips rather than
being inherently related to Swift Bundler.

If you encounter an issue that isn't covered by this article, and isn't a bug
in Swift Bundler (e.g. it's an environment issue or a usage issue), please consider
opening a PR (or GitHub issue) containing the troubleshooting tip, for the benefit
of future developers!

## `xcodebuild`-related issues

When building for non-macOS Apple platforms such as iOS, or building with the
`--xcodebuild` command line option, you may face some Xcode-specific issues.

### Unable to find a destination matching the provided destination specifier

`xcodebuild` sometimes spits out this error even when other tools (such Swift
Bundler's Swift Package Manager backend) can locate a suitable SDK just fine.
It turns out that Xcode ***requires*** you to install the platform SDK
corresponding to your Xcode version, even if you're targeting an older SDK
version and have a suitable older SDK installed.

As an example, you may get this error if you have the iOS 17.2 SDK installed
(from an older Xcode version) and attempt to build an iOS app using Xcode 16
(which requires the iOS 18 SDK).

To resolve this issue, open a project in Xcode, select the run destination
dropdown menu in the tool bar, and click the `GET` button next to the
platform you're building for. If you don't see a `GET` button, your issue
likely has a different underlying cause.
