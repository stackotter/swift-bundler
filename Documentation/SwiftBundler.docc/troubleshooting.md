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

### The developer disk image could not be mounted on this device: The bundle image is missing the requested variant for this device

```
Previous preparation error: The developer disk image could not be mounted on this device.; Error mounting image: 0xe800010f (kAMDMobileImageMounterPersonalizedBundleMissingVariantError: The bundle image is missing the requested variant for this device.)
```

This has been known to occur when attempting to pair iPhone 16s for development
using beta versions of Xcode 16.0, but may of course occur in other situations
as well.

A fix that has worked for some is simply updating to the latest stable version of
Xcode.

### The app identifier "xxx.xxxxxx.xxxxxxxxx" cannot be registered to your development team because it is not available. Change your bundle identifier to a unique string to try again.

Someone else has already registered the bundle identifier under their account.
Bundle identifiers must be unique across all Apple Developer accounts.

As per Quinn "The Eskimo!"'s response in [an Apple Developer Forums thread](https://developer.apple.com/forums/thread/123198),
you can either track down whoever registered the bundle identifier and convince
them to transfer it to you, or you can change to a different bundle identifier.
There is no easy way to do the former, so usually it's best to just go with the
latter.

### The application could not be verified

This can occur when installing an application on a physical device. It usually
relates to mismatches between the app's provisioning profile, and code signing
and/or Info.plist.

Right click your application in Finder (on your Mac) and select `Show Package Contents`.
Then check the following things;

- Ensure that the `CFBundleIdentifier` in `Info.plist` matches the bundle identifier in
  `embedded.mobileprovision` (use Quick Look to inspect the properties of
  `embedded.mobileprovision`).
- Ensure that the app's code signing information matches one of the certificates listed
  in `embedded.mobileprovision`. Use `codesign -dvvvv --extract-certificates path/to/Your.app`
  to list information about the codesigning present in the app.
- Ensure that the value for `application-identifier` in the app's entitlements matches
  the format `TEAM_IDENTIFIER.BUNDLE_IDENTIFIER` and that the team identifier and bundle
  identifier match those in `Info.plist` and `embedded.mobileprovision`. You can use
  `codesign -d --entitlements - path/to/Your.app` to extract the entitlements from the
  app.

If all of those seem to hold and you're still facing the issue, good luck 😬
And please open a GitHub issue or PR to let us know how you end up fixing it!
