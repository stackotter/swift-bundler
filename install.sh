#!/bin/sh
# Build
swift build -c release

# Create directory with correct permissions
sudo mkdir -p -m755 /opt/swift-bundler

# Copy executable
sudo cp .build/release/swift-bundler /opt/swift-bundler

# Add to PATH if it isn't in PATH already
[[ ":$PATH:" != *":/opt/swift-bundler:"* ]] && printf "\nexport PATH=\"/opt/swift-bundler:\$PATH\"" >> ~/.zshenv && echo "Run \`source ~/.zshenv\` for new PATH to take effect"

# Exit with the success code (the previous command makes the exit code a failure when /opt/swift-bundler is already in PATH)
exit 0
