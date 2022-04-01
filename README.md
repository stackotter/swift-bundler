<p align="center">
  <img width="100%" src="banner.png">
</p>

<p align="center">
  <a href="https://swiftpackageindex.com/stackotter/swift-bundler"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fstackotter%2Fswift-bundler%2Fbadge%3Ftype%3Dswift-versions"></a>
  <a href="https://swiftpackageindex.com/stackotter/swift-bundler"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fstackotter%2Fswift-bundler%2Fbadge%3Ftype%3Dplatforms"></a>
  <a href="https://discord.gg/6mUFu3KtAn"><img src="https://img.shields.io/discord/949626773295988746?color=6A7EC2&label=discord&logo=discord&logoColor=ffffff"></a>
</p>

A Swift Package Manager wrapper that allows the creation of macOS apps with Swift packages instead of Xcode projects. My end goal is to be able to create apps for Windows, Linux and macOS with a single Swift codebase. You may also be interested in [SwiftCrossUI](https://github.com/stackotter/swift-cross-ui), a UI framework with a similar goal.

## Supporting Swift Bundler ❤️

If you find Swift Bundler useful, please consider supporting me by [becoming a sponsor](https://github.com/sponsors/stackotter). I spend most of my spare time working on open-source projects, and every single sponsorship helps me focus more time on making high quality tools for the community.

## Contributing 🛠

Contributions of all kinds are very welcome! Just make sure to check out [the contributing guidelines](CONTRIBUTING.md) before getting started. Read through [the open issues](https://github.com/stackotter/swift-bundler/issues) for contribution ideas.

## Documentation 📚

The documentation is hosted on [GitHub pages](https://stackotter.github.io/swift-bundler/documentation/swiftbundler).

## Installation 📦

```sh
sh <(curl -L https://stackotter.dev/swift-bundler/install.sh)
```

## Getting started 🚦

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

The [documentation](https://stackotter.github.io/swift-bundler/documentation/swiftbundler) contains everything you need to know about Swift Bundler.

## Apps made with Swift Bundler 👨‍💻

If you have an app made with Swift Bundler, I'd love to hear about it! Just open an issue or submit a PR to add it to the list.

- [Delta Client](https://github.com/stackotter/delta-client) — A 'Minecraft: Java Edition' compatible Minecraft client written from scratch in Swift



