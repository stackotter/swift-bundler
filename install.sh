#!/bin/sh
# Exit on error
set -e

# Ensure that xcode command-line tools are installed
echo "Ensuring that the Xcode CLTs are installed"
xcode-select --install 2>/dev/null || true

# Build
echo "Building swift-bundler"
swift build -c release

# Create directory with correct permissions
echo "Your password is required to copy the executable to /opt/swift-bundler"
sudo mkdir -p -m755 /opt/swift-bundler

# Copy executable
sudo cp .build/release/swift-bundler /opt/swift-bundler

# Add to PATH if it isn't in PATH already
[[ ":$PATH:" != *":/opt/swift-bundler:"* ]] && printf "\nexport PATH=\"/opt/swift-bundler:\$PATH\"" >> ~/.zshenv && echo "\nRun \`source ~/.zshenv\` to finish installation"

# Exit with the success code (the previous command makes the exit code a failure when /opt/swift-bundler is already in PATH)
exit 0
