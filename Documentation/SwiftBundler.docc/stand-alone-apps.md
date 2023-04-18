# Stand alone apps

What is a stand-alone app, and how you can make one.

## Overview

Stand-alone apps are apps that don't rely on any 3rd-party system-wide dependencies being installed
on the user's system. For example, if you build an executable that uses Gtk3, it isn't stand-alone
and it won't run on any system without Gtk3 installed. However, fear no more! Swift Bundler has a
solution.

## The Swift Bundler solution

When building your app for macOS, try using the `--experimental-stand-alone` flag to automatically
relocate all 3rd-party system-wide dynamic library dependencies of your app into the app bundle.
This works quite effectively for Gtk, however, you will run into issues when trying to create a
universal binary. In particular, universal builds will only be truly universal if the system-wide
dependencies of your app were built as universal binaries when you installed them (not the case if
you used Homebrew). If you are building on Intel, the built app might be able to run on Apple Silicon
because of Rosetta (untested), however it definitely won't work the other way around.
