# Installation

Installing Swift Bundler on your system.

## Recommended (macOS and Linux)

If you're on macOS or Linux, install the latest release of Swift Bundler using
[Mint](https://github.com/yonaskolb/Mint).

```sh
mint install stackotter/swift-bundler
```

> NOTE: If you have previously installed Swift Bundler via the installation script you must delete the `/opt/swift-bundler` directory (requires sudo).

### Latest commit

[Mint](https://github.com/yonaskolb/Mint) can also be used to install directly
from the `main` development branch if you're willing to sacrifice stability in
exchange for the latest and greatest features.

```sh
mint install stackotter/swift-bundler@main
```

## Manual installation (all platforms)

You can install Swift Bundler manually for maximum control. Clone the repo,
build Swift Bundler using the Swift Package Manager, and then copy the
resulting executable to a directory in your path.

```sh
git clone https://github.com/stackotter/swift-bundler
cd swift-bundler

swift build -c release
cp .build/release/swift-bundler /path/to/bin/

# Verify installation
swift bundler --version
```

## Pre-built (macOS)

If you're on macOS, you can use the universal build of `swift-bundler` attached
to recent releases.

```sh
# Replace X.X.X with desired version
curl -O https://github.com/stackotter/swift-bundler/releases/download/vX.X.X/swift-bundler
chmod +x ./swift-bundler
sudo mv ./swift-bundler /usr/local/bin/

# Verify installation
swift bundler --version
```
