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

If you find Swift Bundler useful, please consider supporting me by [becoming a sponsor](https://github.com/sponsors/stackotter). I spend most of my spare time working on open-source projects, and every single sponsorship helps me focus more time on making high quality tools.

## Installation

```sh
git clone https://github.com/stackotter/swift-bundler
cd swift-bundler
sh ./install.sh
```

## Getting started

Use the following commands to create a new app from the SwiftUI template:

```sh
# Create a new app from the SwiftUI template
swift bundler create HelloWorld --template SwiftUI
cd HelloWorld
```

To learn more about package templates, see [the package templates section](#package-templates).

### Running the app

Use the `run` command to build and run the app.

```sh
swift bundler run
```

### Distributing the app

Use the `bundle` command to create an app bundle that you can distribute to users. It is recommended to use the `-c release -u` options to create an optimized universal binary (for running on both Intel and Apple Silicon Macs).

```sh
# Build the app and output it to the current directory.
swift bundler bundle -o . -c release -u
```

### Developing with Xcode

If you want to use xcode as your IDE, run the following command in the package's root directory. This command only needs to be run once unless you delete the `.swiftpm` directory.

```sh
# Creates the files necessary to get xcode to run the package as an app
swift bundler generate-xcode-support
```

To open the package in Xcode, just run `open Package.swift`, or use Finder to open `Package.swift` with Xcode.

## Configuration

Swift Bundler's configuration is stored in the `Bundler.toml` file in the root directory of the package. Below is an example configuration containing all fields;

```toml
[apps.HelloWorld]
product = "HelloWorld" # The package product to create the app from
version = "0.1.0" # The app's version, displayed on macOS's automatic 'About HelloWorld' screen
category = "public.app-category.education"
bundle_identifier = "com.example.HelloWorld"
minimum_macos_version = "11" # The minimum macOS version that the app should run on
icon = "icon.png"
prebuild_script = "./utils/prebuild.sh"
postbuild_script = "./utils/postbuild.sh"

[apps.HelloWorld.extra_plist_entries]
commit = "{COMMIT}" # This could be any key-value pair, 'commit' is just an example
```

Only the `product` and `version` fields are required.

### App Icons

To add an icon to your app, provide a value for the `icon` field of your app's configuration.

The value can either be a path to a `.icns` file, or a `.png` file (which is ideally 1024x1024px, with an alpha channel). If you want to use the same icon for all screen resolutions, just provide the icon as a `png` file. If you want to have a custom level of detail for each resolution, create an `icns` file. The easiest method for creating an `icns` file is to create an `iconset` using Xcode and then run the following command:

```sh
/usr/bin/iconutil -c icns /path/to/AppIcon.iconset
```

### Info.plist customization

If you want to add extra key-value pairs to your app's `Info.plist`, you can specify them in the app's `extra_plist_entries` field. Here's an example configuration that appends the current commit hash to the version string displayed in the `About HelloWorld` screen:

```toml
# ...
[apps.HelloWorld.extra_plist_entries]
CFBundleShortVersionString = "{VERSION}_{COMMIT_HASH}"
```

The `{VERSION}` and `{COMMIT_HASH}` variables get replaced at build time with their respective values. See [the variable substition section](#variable-substitions) for more information.

If you provide a value for a key that is already present in the default `Info.plist`, the default value will be overidden with the value you provide.

### Multi-app packages

Swift Bundler makes it trivial to create multiple apps from one package. Here's an example configuration with a main app and an updater app:

```toml
[apps.Example]
product = "Example"
version = "0.1.0"

[apps.Updater]
product = "Updater"
version = "1.0.1" # The apps can specify separate versions
```

Once multiple apps are defined, certain commands such as `run` and `bundle` require an app name to be provided in order to know which app to operate on.

### Variable substitions

Some configuration fields (currently only `extra_plist_entries`) support variable substitution. This means that anything of the form `{VARIABLE}` within the field's value will be replaced by the variable's value. Below is a list of all supported variables:

- `VERSION`: The app's version
- `COMMIT_HASH`: The commit hash of the git repository at the package's root directory. If there is no git repository, an error will be thrown.

## Package templates

The default package templates are located at `~/Library/Application Support/dev.stackotter.swift-bundler/templates` and are downloaded from [the swift-bundler-templates repository](https://github.com/stackotter/swift-bundler-templates) when the first command requiring the default templates is run.

To learn about creating custom templates, see [the creating custom templates section](#creating-custom-templates).

### List available templates

```sh
swift bundler templates list
# * Skeleton: The bare minimum package with no default UI.
# * SwiftUI: A simple 'Hello, World!' SwiftUI app.
# * SwiftCrossUI: A simple 'Hello, World!' SwiftCrossUI app.
```

### Get information about a template

```sh
swift bundler templates info SwiftUI
# * 'SwiftUI':
#   * A simple 'Hello, World!' SwiftUI app.
#   * Minimum Swift version: 5.5
#   * Platforms: [macOS]
```

### Update available templates

```sh
swift bundler templates update
```

## Contributing

Contributions of all kinds are very welcome! Just make sure to check out [the contributing guidelines](CONTRIBUTING.md) before getting started.

## Advanced usage

### Metal shaders

Swift Bundler supports Metal shaders, however all metal files must be siblings within a single directory and they cannot import any header files from the project. This limitation may be fixed in future versions of Swift Bundler, contributions are welcome! The folder containing the shaders must also be added as resources to the app's target (in `Package.swift`), like so:

```swift
// ...
resources: [
  .process("Render/Shader/"),
]
// ...
```

### Creating custom templates

1. Create a new template 'repository' (a directory that will contain a collection of templates)
2. Create a directory inside the template repository. The name of the directory is the name of your template. (`Base` and `Skeleton` are reserved names)
3. Create a `Template.toml` file (inside the template directory) with the following contents:
   
   ```toml
   description = "My first package template."
   platforms = ["macOS", "Linux"] # Adjust according to your needs, valid values are `macOS` and `Linux`
   ```
4. Add files to the template (see below for details)
5. Test out the template (see [using a custom template](#using-a-custom-template))

Any files within the template directory (excluding `Template.toml`) are copied to the output directory when creating a package. Any occurrence of `{{PACKAGE}}` within the file's relative path is replaced with the package's name. Any occurrence of `{{PACKAGE}}` within the contents of files ending with `.template` is replaced with the package's name and the `.template` file extension is removed.

**All indentation must be tabs (not spaces) so that the `create` command's `--indentation` option functions correctly.**

You can also create a `Base` directory within the template repository. Whenever creating a new package, the `Base` directory is applied first and should contain the common files between all templates, such as the `.gitignore` file. A template can override files in the `Base` template by containing files of the same name.

See [the swift-bundler-templates repository](https://github.com/stackotter/swift-bundler-templates) for some example templates.

### Using a custom template

```sh
swift bundler create MyApp --template MyTemplate --template-repository /path/to/TemplateRepository
```
