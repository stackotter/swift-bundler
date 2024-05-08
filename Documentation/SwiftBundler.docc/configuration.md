# Configuration

Configuring your app.

## Overview

Swift Bundler's configuration is stored in the `Bundler.toml` file in the root directory of a package.

## Example configuration

Below is an example configuration containing all fields.

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

[apps.HelloWorld.plist]
commit = "{COMMIT_HASH}" # This could be any key-value pair, 'commit' is just an example
# You can also define many other kinds of platform-specific fields, as an example, below is
# how you would specify a list of URL schemes (http, ftp, and so on) supported by the app,
# in this example, to allow opening your app from the URL: (ex. helloworld://open)
CFBundleURLTypes = [ { type = "dict", value = { CFBundleTypeRole = 'Viewer', CFBundleURLName = 'HelloWorld', CFBundleURLSchemes = [ 'helloworld' ] } } ]
```

> Note: Only the `product` and `version` fields are required.

## App Icons

To add an icon to your app, provide a value for the `icon` field of your app's configuration.

The value can either be a path to a `.icns` file, or a `.png` file (which is ideally 1024x1024px, with an alpha channel). If you want to use the same icon for all screen resolutions, just provide the icon as a `png` file. If you want to have a custom level of detail for each resolution, create an `icns` file. The easiest method for creating an `icns` file is to create an `iconset` using Xcode and then run the following command:

```sh
/usr/bin/iconutil -c icns /path/to/AppIcon.iconset
```

## Info.plist customization

If you want to add extra key-value pairs to your app's `Info.plist`, you can specify them in the app's `extra_plist_entries` field. Here's an example configuration that appends the current commit hash to the version string displayed in the `About HelloWorld` screen:

```toml
# ...
[apps.HelloWorld.extra_plist_entries]
CFBundleShortVersionString = "{VERSION}_{COMMIT_HASH}"
```

The `{VERSION}` and `{COMMIT_HASH}` variables get replaced at build time with their respective values. See the 'Variable substitions' section for more information.

If you provide a value for a key that is already present in the default `Info.plist`, the default value will be overidden with the value you provide.

## Multi-app packages

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

## Variable substitions

Some configuration fields (currently only `extra_plist_entries`) support variable substitution. This means that anything of the form `{VARIABLE}` within the field's value will be replaced by the variable's value. Below is a list of all supported variables:

- `VERSION`: The app's version
- `COMMIT_HASH`: The commit hash of the git repository at the package's root directory. If there is no git repository, an error will be thrown.
