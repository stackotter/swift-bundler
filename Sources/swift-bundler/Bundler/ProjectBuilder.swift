import AsyncCollections
import Foundation
import SwiftBundlerBuilders
import SystemPackage
import Version

enum ProjectBuilder {
  static let builderProductName = "Builder"

  indirect enum Error: LocalizedError {
    case failedToCloneRepo(URL, ProcessError)
    case failedToWriteBuilderManifest(any Swift.Error)
    case failedToCreateBuilderSourceDirectory(URL, any Swift.Error)
    case failedToSymlinkBuilderSourceFile(any Swift.Error)
    case failedToBuildBuilder(name: String, SwiftPackageManagerError)
    case builderFailed(any Swift.Error)
    case missingProject(name: String, appName: String)
    case missingProduct(project: String, product: String, appName: String)
    case failedToBuildProject(name: String, Error)
    case failedToCopyProduct(source: URL, destination: URL, any Swift.Error)
    case invalidLocalSource(URL)
    case other(any Swift.Error)

    /// An internal error used in control flow.
    case mismatchedGitURL(_ actual: String, expected: URL)

    var errorDescription: String? {
      switch self {
        case .failedToCloneRepo(let gitURL, let error):
          return """
            Failed to clone project source repository '\(gitURL)': \
            \(error.localizedDescription)
            """
        case .failedToCreateBuilderSourceDirectory(_, let error),
          .failedToWriteBuilderManifest(let error),
          .failedToSymlinkBuilderSourceFile(let error):
          return "Failed to generate builder package: \(error.localizedDescription)"
        case .failedToBuildBuilder(let name, _):
          return "Failed to build builder '\(name)'"
        case .builderFailed(let error):
          return "Failed to run builder: \(error.localizedDescription)"
        case .missingProject(let name, let appName):
          return "Missing project named '\(name)' (required by '\(appName)')"
        case .missingProduct(let project, let product, let appName):
          return "Missing product '\(project).\(product)' (required by '\(appName)')"
        case .failedToBuildProject(let name, let error):
          return "'\(name)': \(error.localizedDescription)"
        case .failedToCopyProduct(let source, _, let error):
          return """
            Failed to copy product '\(source.lastPathComponent)': \
            \(error.localizedDescription)
            """
        case .invalidLocalSource(let source):
          return """
            Project source directory \
            '\(source.path(relativeTo: .currentDirectory))' doesn't exist
            """
        case .other(let error):
          return error.localizedDescription
        case .mismatchedGitURL(let actualURL, let expectedURL):
          return """
            Expected repository to have origin url \
            '\(expectedURL.absoluteString)' but had '\(actualURL)'
            """
      }
    }
  }

  struct BuiltProduct {
    var product: ProjectConfiguration.Product.Flat
    var location: URL
  }

  static func buildDependencies(
    _ dependencies: [AppConfiguration.Dependency],
    packageConfiguration: PackageConfiguration.Flat,
    packageDirectory: URL,
    scratchDirectory: URL,
    appProductsDirectory: URL,
    appName: String,
    platform: Platform,
    dryRun: Bool
  ) async -> Result<[String: BuiltProduct], Error> {
    var builtProjects: Set<String> = []
    return await dependencies.tryMap {
      dependency -> Result<(String, BuiltProduct), Error> in
      let projectName = dependency.project

      guard let project = packageConfiguration.projects[projectName] else {
        return .failure(Error.missingProject(name: projectName, appName: appName))
      }

      guard let product = project.products[dependency.product] else {
        return .failure(
          Error.missingProduct(
            project: projectName,
            product: dependency.product,
            appName: appName
          )
        )
      }

      let projectScratchDirectory = ScratchDirectoryStructure(
        scratchDirectory: scratchDirectory / projectName
      )

      let productsDirectoryExists = FileManager.default.itemExists(
        at: projectScratchDirectory.products,
        withType: .directory
      )

      let requiresBuilding = !builtProjects.contains(dependency.project)
      builtProjects.insert(dependency.project)

      let productPath = product.path(whenNamed: dependency.product, platform: platform)
      let builtProduct = projectScratchDirectory.build / productPath
      let productDestination = projectScratchDirectory.products / builtProduct.lastPathComponent

      let successValue = (
        dependency.identifier,
        BuiltProduct(
          product: product,
          location: productDestination
        )
      )

      guard !dryRun else {
        return .success(successValue)
      }

      return await Result.success()
        .andThen(if: requiresBuilding) { _ in
          // Set up required directories and build whole project
          log.info("Building project '\(projectName)'")
          return await Result.success()
            .andThenDoSideEffect(if: productsDirectoryExists) { _ in
              FileManager.default.removeItem(at: projectScratchDirectory.products)
                .mapError(Error.other)
            }.andThen { _ in
              projectScratchDirectory.createRequiredDirectories()
            }.andThen { _ in
              await ProjectBuilder.buildProject(
                projectName,
                configuration: project,
                packageDirectory: packageDirectory,
                scratchDirectory: projectScratchDirectory
              ).mapError { error in
                Error.failedToBuildProject(name: projectName, error)
              }
            }
        }.andThenDoSideEffect { buildDirectory -> Result<Void, Error> in
          log.info("Copying product '\(dependency.identifier)'")
          return FileManager.default.copyItem(
            at: builtProduct,
            to: productDestination,
            onError: Error.failedToCopyProduct
          )
        }.replacingSuccessValue(with: successValue)
    }.map { pairs in
      Dictionary(pairs) { first, _ in first }
    }
  }

  struct ScratchDirectoryStructure {
    var root: URL
    var sources: URL
    var builder: URL
    var build: URL
    var products: URL
    var builderManifest: URL
    var builderSourceFile: URL

    var requireDirectories: [URL] {
      [
        root,
        builder,
        build,
        products,
        builderManifest.deletingLastPathComponent(),
        builderSourceFile.deletingLastPathComponent(),
      ]
    }

    init(scratchDirectory: URL) {
      root = scratchDirectory
      sources = scratchDirectory / "sources"
      builder = scratchDirectory / "builder"
      build = scratchDirectory / "build"
      products = scratchDirectory / "products"
      builderManifest = builder / "Package.swift"
      builderSourceFile = builder / "Sources/Builder/Builder.swift"
    }

    func createRequiredDirectories() -> Result<Void, Error> {
      requireDirectories.filter { directory in
        !FileManager.default.itemExists(at: directory, withType: .directory)
      }.tryForEach { directory in
        FileManager.default.createDirectory(at: directory).mapError(Error.other)
      }
    }
  }

  static func checkoutSource(
    _ source: ProjectConfiguration.Source.Flat,
    at destination: URL,
    packageDirectory: URL
  ) async -> Result<(), Error> {
    func clone(_ repository: URL, to destination: URL) async -> Result<(), Error> {
      await Process.create(
        "git",
        arguments: [
          "clone",
          "--recursive",
          repository.absoluteString,
          destination.path,
        ],
        runSilentlyWhenNotVerbose: false
      ).runAndWait().mapError { error in
        Error.failedToCloneRepo(repository, error)
      }
    }

    let destinationExists = (try? destination.checkResourceIsReachable()) == true

    switch source {
      case .git(let url, let requirement):
        return await Process.create(
          "git",
          arguments: [
            "remote",
            "get-url",
            "origin",
          ],
          directory: destination
        ).getOutput().mapError(Error.other).andThen { output in
          let currentURL = output.trimmingCharacters(in: .whitespacesAndNewlines)
          guard currentURL == url.absoluteString else {
            return .failure(.mismatchedGitURL(currentURL, expected: url))
          }
          return .success()
        }.tryRecover { _ in
          await Result.success().andThen(if: destinationExists) { _ in
            FileManager.default.removeItem(at: destination)
              .mapError(Error.other)
          }.andThen { _ in
            await clone(url, to: destination)
          }
        }.andThen { _ in
          let revision: String
          switch requirement {
            case .revision(let value):
              revision = value
          }

          return await Process.create(
            "git",
            arguments: ["checkout", revision],
            directory: destination
          ).runAndWait().mapError(Error.other)
        }
      case .local(let path):
        return Result.success().andThen(if: destinationExists) { _ in
          FileManager.default.removeItem(at: destination)
            .mapError(Error.other)
        }.andThen { _ in
          let source = packageDirectory / path
          guard source.exists() else {
            return .failure(.invalidLocalSource(source))
          }
          return FileManager.default.createSymlink(
            at: destination,
            withRelativeDestination: source.path(
              relativeTo: destination.deletingLastPathComponent()
            )
          ).mapError(Error.other)
        }
    }
  }

  /// Builds a project and returns the directory containing the built
  /// products on success.
  static func buildProject(
    _ name: String,
    configuration: ProjectConfiguration.Flat,
    packageDirectory: URL,
    scratchDirectory: ScratchDirectoryStructure
  ) async -> Result<Void, Error> {
    // Just sitting here to raise alarms when more types are added
    switch configuration.builder.type {
      case .wholeProject:
        break
    }

    return await Result.success()
      .andThen { _ in
        await checkoutSource(
          configuration.source,
          at: scratchDirectory.sources,
          packageDirectory: packageDirectory
        )
      }
      .andThen { _ in
        // Create builder source file symlink
        Result {
          let masterBuilderSourceFile = packageDirectory / configuration.builder.name
          if FileManager.default.fileExists(atPath: scratchDirectory.builderSourceFile.path) {
            try FileManager.default.removeItem(at: scratchDirectory.builderSourceFile)
          }
          try FileManager.default.createSymbolicLink(
            at: scratchDirectory.builderSourceFile,
            withDestinationURL: masterBuilderSourceFile
          )
        }.mapError(Error.failedToSymlinkBuilderSourceFile)
      }
      .andThen { _ in
        // Create/update the builder's Package.swift
        await SwiftPackageManager.getToolsVersion(packageDirectory)
          .mapError(Error.other)
          .map { toolsVersion in
            generateBuilderPackageManifest(
              toolsVersion,
              builderAPI: configuration.builder.api.normalized(
                usingDefault: SwiftBundler.gitURL
              ),
              rootPackageDirectory: packageDirectory,
              builderPackageDirectory: scratchDirectory.builder
            )
          }
          .andThen { manifestContents in
            manifestContents.write(to: scratchDirectory.builderManifest)
              .mapError(Error.failedToWriteBuilderManifest)
          }
      }
      .andThen { _ in
        // Build the builder
        let buildContext = SwiftPackageManager.BuildContext(
          packageDirectory: scratchDirectory.builder,
          scratchDirectory: scratchDirectory.builder / ".build",
          configuration: .debug,
          architectures: [.current],
          platform: .host,
          additionalArguments: [],
          isGUIExecutable: false
        )

        return await SwiftPackageManager.build(
          product: builderProductName,
          buildContext: buildContext
        ).andThen { _ in
          await SwiftPackageManager.getProductsDirectory(buildContext)
        }.mapError { error in
          Error.failedToBuildBuilder(name: configuration.builder.name, error)
        }
      }
      .andThen { productsDirectory in
        let builderFileName = HostPlatform.hostPlatform.executableFileName(
          forBaseName: builderProductName
        )

        let context = _BuilderContextImpl(
          buildDirectory: scratchDirectory.build
        )

        let inputPipe = Pipe()
        let process = Process()

        process.executableURL = productsDirectory / builderFileName
        process.standardInput = inputPipe
        process.currentDirectoryURL = scratchDirectory.sources
          .actuallyResolvingSymlinksInPath()
        process.arguments = []

        let processWaitSemaphore = AsyncSemaphore(value: 0)

        process.terminationHandler = { _ in
          processWaitSemaphore.signal()
        }

        return await Result {
          _ = try process.run()
          let data = try JSONEncoder().encode(context).get()
          inputPipe.fileHandleForWriting.write(data)
          inputPipe.fileHandleForWriting.write("\n")
          try? inputPipe.fileHandleForWriting.close()
          try await processWaitSemaphore.wait()
          return Int(process.terminationStatus)
        }.andThen { exitStatus in
          if exitStatus == 0 {
            return .success()
          } else {
            return .failure(ProcessError.nonZeroExitStatus(exitStatus))
          }
        }.mapError(Error.builderFailed)
      }
  }

  static func generateBuilderPackageManifest(
    _ swiftVersion: Version,
    builderAPI: ProjectConfiguration.Source.Flat,
    rootPackageDirectory: URL,
    builderPackageDirectory: URL
  ) -> String {
    let dependency: String
    switch builderAPI {
      case .local(let path):
        let fullPath = rootPackageDirectory / path
        let relativePath = fullPath.path(relativeTo: builderPackageDirectory)
        dependency = """
                  .package(
                      name: "swift-bundler",
                      path: "\(relativePath)"
                  )
          """
      case .git(let url, let requirement):
        let revision: String
        switch requirement {
          case .revision(let value):
            revision = value
        }
        dependency = """
                  .package(
                      url: "\(url.absoluteString)",
                      revision: "\(revision)"
                  )
          """
    }

    return """
      // swift-tools-version:\(swiftVersion.major).\(swiftVersion.minor)
      import PackageDescription

      let package = Package(
          name: "Builder",
          platforms: [.macOS(.v10_15)],
          products: [
              .executable(name: "Builder", targets: ["Builder"])
          ],
          dependencies: [
      \(dependency)
          ],
          targets: [
              .executableTarget(
                  name: "\(builderProductName)",
                  dependencies: [
                      .product(name: "SwiftBundlerBuilders", package: "swift-bundler")
                  ]
              )
          ]
      )
      """
  }
}
