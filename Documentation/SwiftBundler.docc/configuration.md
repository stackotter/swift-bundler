# Configuration

Configuring your app.

## Overview

Swift Bundler's configuration is stored in the `Bundler.toml` file in the root
directory of a package.

## Example configuration

Below is an example configuration containing all fields.

```toml
format_version = 2

# `HelloWorld` here is the app's name. Use double quotes if your app's name
# contains special characters such as spaces.
[apps.HelloWorld]
# The SwiftPM package executable product to bundle
product = "HelloWorld"
# The app's version, displayed on macOS's automatic 'About HelloWorld' screen.
version = "0.1.0"
# The app's identifier, used by bundlers which require reverse domain name
# identifiers.
identifier = "com.example.HelloWorld"
# Only used by the Darwin bundler at the moment. Corresponds to Apple's category
# identifiers. See https://developer.apple.com/documentation/bundleresources/information-property-list/lsapplicationcategorytype
category = "public.app-category.education" # Optional
# The app's icon. Must be a 1024x1024px PNG file, or a `.icns` file. `.icns`
# files only work on Apple platforms.
icon = "icon.png" # Optional

# Extra entries for your app's Info.plist file. Currently has no effect on
# Linux.
[apps.HelloWorld.plist]
# This could be any key-value pair, `CFBundleShortVersionString` is just an
# example. Patterns of the form `$(...)` get replaced with their corresponding
# values. See 'Variable substitutions' below.
CFBundleShortVersionString = "$(VERSION)_$(COMMIT_HASH)"
# You can also define many other kinds of complex fields that you want. Below
# is how you would specify a list of URL schemes (http, ftp, and so on)
# supported by a macOS app.
CFBundleURLTypes = [ { type = "dict", value = { CFBundleTypeRole = 'Viewer', CFBundleURLName = 'HelloWorld', CFBundleURLSchemes = [ 'helloworld' ] } } ]
```

> Note: Only the `product`, `version` and `identifier` fields are required.

## Schema

Some editors allow JSON schemas to be used when editing TOML files. If you're
using such an editor, Swift Bundler has a [Bundler.schema.json](https://github.com/stackotter/swift-bundler/blob/main/Bundler.schema.json)
schema file describing the `Bundler.toml` format.

If the schema is ever outdated, you can use [generate_schema.sh](https://github.com/stackotter/swift-bundler/blob/main/generate_schema.sh)
to generate the schema from the Swift Bundler source code as a quick fix, but
make sure to let me know anyway so that I can update it for everyone!

## App Icons

To add an icon to your app, provide a value for the `icon` field of your app's
configuration.

Icons can either be `.icns` files or 1024x1024px `.png` files. `.icns` is not
compatible with Linux. If you want cross-platform support or you want to use
the same icon for all screen resolutions, provide the icon as a `.png` file.
Otherwise use a `.icns` file. The easiest method for creating an `icns` file is
to create an `iconset` using Xcode and then run the following command.

```sh
/usr/bin/iconutil -c icns /path/to/AppIcon.iconset
```

## Info.plist customization

If you want to add extra key-value pairs to your app's `Info.plist`, you can
specify them in the app's `plist` field. Here's an example configuration that
appends the current commit hash to the version string displayed in the
`About HelloWorld` screen of the `HelloWorld` app.

```toml
# ...
[apps.HelloWorld.plist]
CFBundleShortVersionString = "$(VERSION)_$(COMMIT_HASH)"
```

Patterns of the form `$(...)` get replaced with their corresponding values. See
[Variable substitutions](#Variable-substitutions) below.

If you provide a value for a key that is already present in the default
`Info.plist`, the default value will be overidden with the value you provide.

### Type ambiguity

Certain Property List field types such as `data`, `date`, and `integer` can't be
distinguished using TOML syntax alone. Swift Bundler will throw an error if any
values cannot be decoded unambiguosly.

To disambiguate, you can convert the value to a TOML dictionary with separate
`type` and `value` fields. For this reason, dictionaries with a `type` field
also require disambiguation.

Property List field type | Requires disambiguation? | Example
-----------|---------------------|----------------------
`string` | no | `MyKey = "My string"`
`boolean` | no | `MyKey = true`
`array` | no | `MyKey = [1, "A string"]`
`real` | no, *unless a whole number* | `MyKey = 1.2` or `MyKey = { type = "real", value = 1.0 }`
`integer` | no | `MyKey = 1`
`date` | **yes** | `MyKey = { type = "date", value = "2024-12-02T10:08:00Z" }`
`data` | **yes** | `MyKey = { type = "data", value = "b3R0ZXIncyBpbiBhIHN0YWNrPw==" }`, must be base64 encoded
`dict` | no, *unless it contains a `type` key* | `MyKey = { major = 1, minor = 0 }` or `MyKey = { type = "dict", value = { type = 1, tag = 0 } }`

## Multi-app packages

Swift Bundler makes it trivial to create multiple apps from one package. Here's
an example configuration with a main app and an updater app.

```toml
[apps.Example]
identifier = "com.example.Example"
product = "Example"
version = "0.1.0"

[apps.Updater]
identifier = "com.example.Updater"
product = "Updater"
version = "1.0.1"
```

Once multiple apps are defined, certain commands such as `run` and `bundle`
require an app name in order to know which app to operate on.

```sh
# Run the main app.
swift bundler run Example
# Run the updater.
swift bundler run Updater
```

## Variable substitutions

Some configuration fields (currently only `plist`) support variable
substitution. This means that anything of the form `$(VARIABLE)` within the
field's value will be replaced by the variable's value. Below is a list of all
supported variables.

Name | Value
-----|------
`VERSION` | The app's version
`COMMIT_HASH` | The commit hash of the git repository at the package's root directory. If there is no git repository, an error will be thrown.
