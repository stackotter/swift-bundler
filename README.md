# swift-bundler

A Swift Package Manager wrapper that allows the creation of MacOS apps with Swift packages instead of Xcode projects. My motivation is that I think Xcode projects are a lot more restrictive than Swift packages, and Swift packages are less convoluted. My end goal is to be able to create Swift apps for Windows, Linux and MacOS with a single codebase.

## Usage

### Init

```sh
# Create a new swift package and set it up for bundling
swift bundler init
```

It is also possible to run the command in an existing swift package, but there are some things to look out for. Make sure your package contains a `main.swift` file. Make sure to use the `--name` flag if the name of your executable product differs from the name of your package. The macOS platform version should in `Package.swift` should be at least 11.0, earlier versions will likely work as well, but they are not tested.

### Generate xcodeproj

If you want to use xcode as your ide, run this in the package directory. Make sure you've run init first. Each time you update some configuration or add a build script you'll want to rerun this command. The generated xcodeproj has some limitations so build progress has to be displayed in a separate window created by the bundler and isn't shown in the normal xcode progress bar. But the progress bar window automatically appears at the top right of the screen that currently contains your mouse so it should feel pretty natural to use.

```sh
# Creates an xcodeproj file for using xcode as the ide
swift bundler generate-xcodeproj
```

### Build

```sh
# Build the app and output the .app to the specified dir
# If no directory is specified the default output dir is .build/bundler
swift bundler build -o [dir]
```

### Build and run

```sh
# Builds and runs the app
swift bundler run
```

### Help

If you want to see all available options just add `--help` to the end, (e.g. `swift bundler run --help`).
