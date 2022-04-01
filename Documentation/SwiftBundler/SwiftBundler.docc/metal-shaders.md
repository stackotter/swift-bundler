# Metal shaders

Using Metal shaders with Swift Bundler.

## Overview

SwiftPM handles Metal shaders a bit differently compared to Xcode. This page documents the differences that you need to know about.

## Compiling Metal shaders

Swift Bundler supports automatic compilation of Metal shaders, however all Metal shader files must be siblings within a single directory and they cannot import any header files from the project. This limitation may be fixed in future versions of Swift Bundler, contributions are welcome! The folder containing the shaders must also be added to the app's target (in `Package.swift`) as a resource, like so.

```swift
// ...
resources: [
  .process("Render/Shader/"),
]
// ...
```

## Loading Metal shaders

Loading Metal shaders is a bit more complicated than usual when using Swift Bundler, so here's an example to get you started.

```swift
// Replace 'Product_Product' according to the name of your app's product 
guard
  let bundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Product_Product.bundle")),
  let libraryURL = bundle.url(forResource: "default", withExtension: "metallib")
else {
  // Handle error
}

let library = try device.makeLibrary(URL: libraryURL)
```
