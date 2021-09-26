# swift-bundler

A Swift Package Manager wrapper that allows the creation of MacOS apps with Swift packages instead of Xcode projects. My motivation is that I think Xcode projects are a lot more restrictive than Swift packages, and Swift packages are less convoluted. My end goal is to be able to create Swift apps for Windows, Linux and MacOS with a single codebase.

## Installation

```sh
git clone https://github.com/stackotter/swift-bundler
cd swift-bundler
sh ./build_and_install.sh
```

## Usage

### Init

```sh
# Create a new swift package and set it up for bundling
swift bundler init
```

It is also possible to run the command in an existing swift package, but there are some things to look out for. Make sure your package contains a `main.swift` file. Make sure to use the `--name` flag if the name of your executable product differs from the name of your package. The macOS platform version should in `Package.swift` should be at least 11.0, earlier versions will likely work as well, but they are not tested.

### Configuration

Running `swift bundler init` creates a `Bundle.json` file which contains all the configuration for the app. Below is an example configuration;

```json
{
  "buildNumber" : 1,
  "bundleIdentifier" : "com.example.bundler-hello-world",
  "category" : "public.app-category.games",
  "minOSVersion" : "11.0",
  "versionString" : "0.1.0"
}
```

Remember to change this configuration to match your project.

### Generate xcodeproj

If you want to use xcode as your ide, run this in the package directory. Make sure you've run init first. Each time you update some configuration you'll want to re-run this command. The generated xcodeproj has some limitations so build progress has to be displayed in a separate window created by the bundler and isn't shown in the normal xcode progress bar. But the progress bar window automatically appears at the top right of the screen that currently contains your mouse so it should feel pretty natural to use.

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

### Custom build scripts

Both prebuild and postbuild scripts are supported. Just create the `prebuild.sh` and/or `postbuild.sh` files in the root directory of your project and they will automatically be run with the next build. No extra configuration required.

### App Icons

There are two ways to add custom app icons to a bundle project.

1. The simplest way is to add an Icon1024x1024.png file in the root directory of your project and the bundler will automatically convert it to all the required sizes and create the AppIcon.icns in the app's resources. The png file must have an alpha channel and should be 1024x1024 but this isn't checked when building.
2. If you want to have different versions of your icon for different file sizes you can create a custom AppIcon.icns and add it to the root directory. You can even generate it from an IconSet in a custom prebuild script! (just see createIcns in Utils.swift for how this is done).

If both are present, `AppIcon.icns` is used.

### Help

If you want to see all available options just add `--help` to the end, (e.g. `swift bundler run --help`).