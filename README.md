<p align="center">
  <img width="100%" src="banner.png">
</p>

<p align="center">
  <a href="https://swiftpackageindex.com/stackotter/swift-bundler"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fstackotter%2Fswift-bundler%2Fbadge%3Ftype%3Dswift-versions"></a>
  <a href="https://discord.gg/6mUFu3KtAn"><img src="https://img.shields.io/discord/949626773295988746?color=6A7EC2&label=discord&logo=discord&logoColor=ffffff"></a>
</p>

<p align="center">
  An Xcodeproj-less tool for creating cross-platform Swift apps.
</p>

## Supporting Swift Bundler ❤️

If you find Swift Bundler useful, please consider supporting me by [becoming a sponsor](https://github.com/sponsors/stackotter). I spend most of my spare time working on open-source projects, and each sponsorship helps me focus more time on making high quality tools for the community.

## Documentation 📚

The documentation is hosted on [GitHub pages](https://stackotter.github.io/swift-bundler/documentation/swiftbundler).

## Installation 📦

Install the latest version of Swift Bundler with [mint](https://github.com/yonaskolb/Mint):

```sh
mint install stackotter/swift-bundler
```

If you have previously installed Swift Bundler via the installation script you must delete the `/opt/swift-bundler` directory (requires sudo).

For more installation methods, see [the documentation](https://stackotter.github.io/swift-bundler/documentation/swiftbundler/installation).

## Getting started 🚦

After installing Swift Bundler, package templates make it quick to get started. The following sections walk you through creating and running a simple 'Hello, World!' SwiftUI app.

### Creating a SwiftUI app

```sh
# Create a new app from the SwiftUI template.
swift bundler create HelloWorld --template SwiftUI
cd HelloWorld
```

### Running the app

```sh
# Build and run the app.
swift bundler run
```

### Using Xcode as your IDE

```sh
# Creates the files necessary to get xcode to run the package as an app.
# Only needs to be run once unless you delete the `.swiftpm` directory.
swift bundler generate-xcode-support

# Open the package in Xcode
open Package.swift
```

### Learning more

To learn more about Swift Bundler refer to the [documentation](https://stackotter.github.io/swift-bundler/documentation/swiftbundler).

## Contributing 🛠

Contributions of all kinds are very welcome! Just make sure to check out [the contributing guidelines](CONTRIBUTING.md) before getting started. Read through [the open issues](https://github.com/stackotter/swift-bundler/issues) for contribution ideas.

## Apps made with Swift Bundler 👨‍💻

If you have made an app with Swift Bundler, I'd love to hear about it! Just open an issue or submit a PR to add it to the list.

- [Delta Client](https://github.com/stackotter/delta-client) — A 'Minecraft: Java Edition' compatible Minecraft client written from scratch in Swift
