# Creating an app

Creating a hello world app.

## Overview

Use the following command to create a new app from the SwiftUI template.

```sh
# Create a new app from the SwiftUI template
swift bundler create HelloWorld --identifier com.example.HelloWorld --template SwiftUI
cd HelloWorld
```

To learn more about package templates, see <doc:package-templates>.

## Running the app

Use the `run` command to build and run the app.

```sh
swift bundler run
```

## Distributing the app

Use the `bundle` command to create an app bundle that you can distribute to users. It is recommended that you use the `-c release -u` options to create an optimized universal binary (for running on both Intel and Apple Silicon Macs).

```sh
# Build the app and output it to the current directory.
swift bundler bundle -o . -c release -u
```

## Running the app from Xcode

Run the `generate-xcode-support` command if you want to use Xcode as your IDE. This command only needs to be run once unless you delete the `.swiftpm` directory.

```sh
# Creates the files necessary to get xcode to run the package as an app
swift bundler generate-xcode-support
```

To open the package in Xcode, just run `open Package.swift`, or use Finder to open `Package.swift` with Xcode. To run the app, just select the scheme with the same name as your app and then click run.


