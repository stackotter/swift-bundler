# Mac Catalyst

Targeting Mac Catalyst.

## Overview

Swift Bundler supports targeting Mac Catalyst. There are few configuration options you should know about before getting started.

## Building for Mac Catalyst

To build for Mac Catalyst, add `--platform macCatalyst` to your command line arguments.

This uses xcodebuild behind the scenes when building your app's main executable in order to work around cross-compilation issues with SwiftPM.

> Note: Force Swift Bundler to use SwiftPM by adding the `--no-xcodebuild` command line argument. This will lead incorrect behaviour of compile-time conditionals (i.e. they will get evaluated for the host platform) but can be useful for simple apps.

## Mac Catalyst configuration

Swift Bundler allows you to configure the interface idiom used by your Mac Catalyst app. Xcode calls this option `Mac Catalyst Interface`.

The supported interface idioms are `ipad` and `mac`. Xcode calls these options `Scaled to Match iPad` and `Optimize for Mac` respectively. Swift Bundler defaults to `ipad`, as does Xcode.

To specify the Mac Catalyst interface idiom for your app,

1. Create a Mac Catalyst specific configuration overlay, and
2. Set `interface_idiom` to `"mac"` or `"ipad"`

```toml
[[apps.YourApp.overlays]]
condition = "platform(macCatalyst)"
interface_idiom = "mac" # default: "ipad"
```

The overlay is required because the `interface_idiom` configuration field is only available when targeting Mac Catalyst.
