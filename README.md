<p align="center">
  <img width="100%" src="banner.png">
</p>

<p align="center">
  <a href="https://swiftpackageindex.com/stackotter/swift-bundler"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fstackotter%2Fswift-bundler%2Fbadge%3Ftype%3Dswift-versions"></a>
  <a href="https://swiftpackageindex.com/stackotter/swift-bundler"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fstackotter%2Fswift-bundler%2Fbadge%3Ftype%3Dplatforms"></a>
  <a href="https://discord.gg/6mUFu3KtAn"><img src="https://img.shields.io/discord/949626773295988746?color=6A7EC2&label=discord&logo=discord&logoColor=ffffff"></a>
</p>

A Swift Package Manager wrapper that allows the creation of macOS apps with Swift packages instead of Xcode projects. My motivation is that I think Xcode projects are a lot more restrictive than Swift packages, and Swift packages are less convoluted. My end goal is to be able to create Swift apps for Windows, Linux and MacOS with a single codebase. You may also be interested in [SwiftCrossUI](https://github.com/stackotter/swift-cross-ui), a UI framework with a similar goal.

## Installation

```sh
git clone https://github.com/stackotter/swift-bundler
cd swift-bundler
sh ./install.sh
```

## Getting started

To create your first app with Swift Bundler, the `create` command is an easy place to get started.

```sh
# Create a new swift package and from the SwiftUI template and set it up for Swift Bundler.
swift bundler create HelloWorld --template SwiftUI
```

### Build

```sh
# Build and bundle the app. The default output directory is .build/bundler, but
# it can be changed using the '-o' option.
swift bundler bundle
```

### Build and run

```sh
# Builds and runs the app. The build configuration can
# be specified with the '-c' option (e.g. '-c debug').
swift bundler run
```

### Configuration

Running `swift bundler create` creates a `Bundler.toml` file which contains all the configuration for the app. Below is an example configuration;

```toml
[apps.HelloWorld]
product = "HelloWorld"
version = "0.1.0"
```

If you want to add another app to the same package, it's easy, just duplicate that configuration section and replace the app name and product.

Here's an example of a configuration file containing example values for all fields:

```toml
[apps.HelloWorld]
product = "HelloWorld"
version = "0.1.0"
category = "public.app-category.education"
bundle_identifier = "com.example.HelloWorld"
minimum_macos_version = "11"

[apps.HelloWorld.extra_plist_entries]
commit = "{COMMIT}"
```

### Xcode support

If you want to use xcode as your ide, run this in the package's root directory. This command only needs to be run once unless you delete the `.swiftpm` directory.

```sh
# Creates the files necessary to get xcode to run the package as an app
swift bundler generate-xcode-support
```

To open the package in Xcode, just run `open Package.swift` or open `Package.swift` with Xcode through Finder.

### Custom build scripts

Both prebuild and postbuild scripts are supported. Just create the `prebuild.sh` and/or `postbuild.sh` files in the root directory of your project and they will automatically be run with the next build. No extra configuration required. `prebuild.sh` is run before building, and `postbuild.sh` is run after bundling (creating the `.app`).

### App Icons

There are two ways to add custom app icons to a bundler project.

1. The simplest way is to add a file called `Icon1024x1024.png` to the root directory of your package. The png file must have an alpha channel and should be 1024x1024 but this isn't checked when building.
2. If you want to have different versions of your icon for different resolutions you can add an `AppIcon.icns` iconset in the root directory of your package.

If both are present, `AppIcon.icns` is used because it is more specific.

### Info.plist customization

If you want to add extra key-value pairs to your app's Info.plist, you can specify them in an app's `extraPlistEntries` field. Here's an example where the version displayed on the app's about screen is updated to include the current commit hash:

```toml
[app.HelloWorld.extra_plist_entries]
CFBundleShortVersionString = "{VERSION}_{COMMIT_HASH}"
```

The `{VERSION}` and `{COMMIT_HASH}` variables get replaced at build time with their respective values. See [the variable substition section](#variable-substitions) for more information.

If you provide a value for a key that is already present in the default Info.plist, the default value will be overidden with the value you provide.

### Variable substitions

Some configuration fields (currently only `extraPlistEntries`) support variable substitution. This means that anything of the form `{VARIABLE}` within the field's value will be replaced by the variable's value. Below is a list of all supported variables:

- `VERSION`: The app's configured version
- `COMMIT_HASH`: The commit hash of the git repository at the package's root directory. If there is no git repository, an error will be thrown.

### Help

If you want to see all available options just use the `help` command (e.g. `swift bundler help run`).

## Advanced usage

### Metal shaders

Swift Bundler supports Metal shaders, however all metal files must be siblings within a single directory and they cannot import any header files from the project. This limitation may be fixed in future versions of Swift Bundler, contributions are welcome! The folder containing the shaders must also be added to the app's target (in `Package.swift`) as resources to process, like so:

```swift
// ...
resources: [
  .process("Render/Shader/"),
]
// ...
```