import Crypto
import Foundation
import XMLCoder

/// The bundler for creating Windows MSI installers. The output of this bundler
/// isn't directly executable.
enum MSIBundler: Bundler {
  typealias Context = Void

  static let outputIsRunnable = false

  enum Error: LocalizedError {
    case failedToRunGenericBundler(GenericWindowsBundler.Error)
    case failedToWriteWXSFile(Swift.Error)
    case failedToSerializeWXSFile(Swift.Error)
    case failedToEnumerateBundle(Swift.Error)
    case failedToRunWiX(command: String, ProcessError)

    var errorDescription: String? {
      switch self {
        case .failedToRunGenericBundler(let error):
          return error.localizedDescription
        case .failedToWriteWXSFile(let error):
          return """
            Failed to write WiX configuration file: \(error.localizedDescription)
            """
        case .failedToSerializeWXSFile(let error):
          return """
            Failed to serialize WiX configuration file: \
            \(error.localizedDescription)
            """
        case .failedToEnumerateBundle(let error):
          return """
            Failed to enumerate generic app bundle structure: \
            \(error.localizedDescription)
            """
        case .failedToRunWiX(_, let error):
          return """
            Failed to run WiX MSI builder: \(error.localizedDescription)
            """
      }
    }
  }

  static func intendedOutput(
    in context: BundlerContext,
    _ additionalContext: Void
  ) -> BundlerOutputStructure {
    return BundlerOutputStructure(
      bundle: context.outputDirectory / "\(context.appName).msi",
      executable: nil,
      additionalOutputs: []
    )
  }

  static func bundle(
    _ context: BundlerContext,
    _ additionalContext: Void
  ) async -> Result<BundlerOutputStructure, Error> {
    let outputStructure = intendedOutput(in: context, additionalContext)

    let wxsFile = context.outputDirectory / "project.wxs"
    return await GenericWindowsBundler.bundle(
      context,
      GenericWindowsBundler.Context()
    )
    .mapError(Error.failedToRunGenericBundler)
    .andThenDoSideEffect {
      (genericBundlerOutput: GenericWindowsBundler.BundleStructure) in
      generateWXSFileContents(
        genericBundle: genericBundlerOutput,
        appName: context.appName,
        appConfiguration: context.appConfiguration
      ).andThen { contents in
        contents.write(to: wxsFile).mapError(Error.failedToWriteWXSFile)
      }
    }
    .andThenDoSideEffect { genericBundlerOutput in
      log.info("Running WiX MSI builder")
      let process = Process.create(
        "wix",
        arguments: [
          "build",
          "-b", genericBundlerOutput.root.path,
          "-o", outputStructure.bundle.path,
          wxsFile.path,
        ],
        runSilentlyWhenNotVerbose: false
      )
      return await process.runAndWait().mapError { error in
        .failedToRunWiX(command: process.commandStringForLogging, error)
      }
    }
    .replacingSuccessValue(with: outputStructure)
  }

  static func generateWXSFileContents(
    genericBundle: GenericWindowsBundler.BundleStructure,
    appName: String,
    appConfiguration: AppConfiguration.Flat
  ) -> Result<Data, Error> {
    generateWXSFile(
      genericBundle: genericBundle,
      appName: appName,
      appConfiguration: appConfiguration
    ).andThen { file in
      let encoder = XMLEncoder()
      encoder.outputFormatting = [.prettyPrinted]
      return Result {
        try encoder.encode(
          file,
          withRootKey: "Wix",
          header: XMLHeader(version: 1, encoding: "UTF-8")
        )
      }.mapError(Error.failedToSerializeWXSFile)
    }
  }

  static func generateWXSFile(
    genericBundle: GenericWindowsBundler.BundleStructure,
    appName: String,
    appConfiguration: AppConfiguration.Flat
  ) -> Result<WXSFile, Error> {
    // TODO: Allow manufacturer to be configured
    // For now drop the last segment of the app's bundle identifier.
    let manufacturer = appConfiguration.identifier.split(separator: ".")
      .dropLast().joined(separator: ".")

    // Assume that the bundle identifier will stay the same for any given app.
    // This feels like a reasonable requirement for app to get stable upgrade
    // codes.
    let upgradeCode = GUID.random(
      withSeed: appConfiguration.identifier
    ).description

    return enumerate(
      genericBundle.root,
      excluding: [genericBundle.mainExecutable],
      id: "InstallFolder"
    ).map { installFolder in
      let mainExecutablePath = genericBundle.mainExecutable.path(
        relativeTo: genericBundle.root
      )

      let package = WXSFile.Package(
        language: .english,
        manufacturer: manufacturer,
        name: appName,
        upgradeCode: upgradeCode,
        version: appConfiguration.version,
        majorUpgrade: WXSFile.MajorUpgrade(
          downgradeErrorMessage:
            "A later version of [ProductName] is already installed. Setup will now exit"
        ),
        mediaTemplate: WXSFile.MediaTemplate(embedCab: .yes),
        standardDirectories: [
          WXSFile.StandardDirectory(
            id: "ProgramFilesFolder",
            directories: [installFolder.renamed(to: appName)]
          ),
          WXSFile.StandardDirectory(
            id: "ProgramMenuFolder",
            directories: [
              WXSFile.Directory(id: "AppShortcutFolder", name: appName)
            ]
          ),
        ],
        componentGroups: [
          WXSFile.ComponentGroup(
            id: "Components",
            directory: "InstallFolder",
            components: [
              WXSFile.Component(
                id: "MainExecutable",
                files: [
                  WXSFile.File(
                    id: "MainExecutable",
                    source: mainExecutablePath
                  )
                ]
              ),
              WXSFile.Component(
                id: "ShortcutComponent",
                shortcuts: [
                  WXSFile.Shortcut(
                    id: "ApplicationStartMenuShortcut",
                    directory: "AppShortcutFolder",
                    advertise: .no,
                    name: appName,
                    description: "Launch \(appName)",
                    target: "[#MainExecutable]",
                    workingDirectory: "InstallFolder"
                  ),
                  WXSFile.Shortcut(
                    id: "UninstallShortcut",
                    directory: "AppShortcutFolder",
                    advertise: .no,
                    name: "\(appName) uninstall",
                    description: "Uninstalls \(appName)",
                    target: "[System64Folder]msiexec.exe",
                    arguments: "/x [ProductCode]"
                  ),
                ],
                folderRemovals: [
                  WXSFile.RemoveFolder(id: "InstallFolder", on: "uninstall"),
                  WXSFile.RemoveFolder(
                    id: "AppShortcutFolder",
                    directory: "AppShortcutFolder",
                    on: "uninstall"
                  ),
                ],
                registryValues: [
                  WXSFile.RegistryValue(
                    root: "HKCU",
                    key: "Software\\Microsoft\\\(appConfiguration.identifier)",
                    name: "installed",
                    type: "integer",
                    value: "1",
                    keyPath: .yes
                  )
                ]
              ),
            ]
          )
        ]
      )

      return WXSFile(
        xmlns: "http://wixtoolset.org/schemas/v4/wxs",
        package: package
      )
    }
  }

  /// Enumerates a directory to produce a WXS directory description.
  /// - Parameters:
  ///   - directory: The directory to enumerate.
  ///   - root: The root directory that all paths should be relative to.
  ///     Defaults to `directory`.
  ///   - id: The WXS id to give the directory.
  private static func enumerate(
    _ directory: URL,
    withRespectTo root: URL? = nil,
    excluding excludedItems: [URL] = [],
    id: String? = nil
  ) -> Result<WXSFile.Directory, Error> {
    let root = root ?? directory
    let excludedPaths = excludedItems.map(\.path)
    return FileManager.default.contentsOfDirectory(at: directory)
      .mapError(Error.failedToEnumerateBundle)
      .map { items in
        return items.filter { item in
          // For some reason URL comparison seems to be a little broken on Windows.
          // URLs with identical paths get evaluated as distinct URLs, so we have to
          // convert to paths before comparison.
          return !excludedPaths.contains(item.path)
        }
      }
      .andThen { items in
        let files = items.filter { item in
          FileManager.default.itemExists(at: item, withType: .file)
        }.map { file in
          let source = file.path(relativeTo: root)
          return WXSFile.File(source: source)
        }

        let directories = items.filter { item in
          FileManager.default.itemExists(at: item, withType: .directory)
        }

        // Enumerate each directory and then combine files and directories into
        // a description of the current directory.
        return directories.tryMap { subdirectory in
          enumerate(subdirectory, withRespectTo: root, excluding: excludedItems)
        }.map { directories in
          WXSFile.Directory(
            id: id,
            name: directory.lastPathComponent,
            directories: directories,
            files: files
          )
        }
      }
  }

  struct GUID: CustomStringConvertible {
    var value: (UInt64, UInt64)

    var description: String {
      func hex(_ value: UInt64, bytes: Int) -> String {
        String(format: "%0\(bytes * 2)X", value)
      }

      let chunk0 = value.0 >> 32
      let chunk1 = (value.0 >> 16) & 0xffff
      let chunk2 = value.0 & 0xffff
      let chunk3 = (value.1 >> 48) & 0xffff
      let chunk4 = value.1 & 0xffff_ffff_ffff

      return
        """
        \(hex(chunk0, bytes: 4))-\(hex(chunk1, bytes: 2))-\
        \(hex(chunk2, bytes: 2))-\(hex(chunk3, bytes: 2))-\
        \(hex(chunk4, bytes: 6))
        """
    }

    static func random(withSeed seed: String) -> GUID {
      let hash = SHA256.hash(data: Data(seed.utf8))
      let value = hash.withUnsafeBytes { pointer in
        let buffer = pointer.assumingMemoryBound(to: UInt64.self)
        return (
          buffer[0],
          buffer[1]
        )
      }
      return GUID(value: value)
    }
  }

  struct WXSFile: Codable {
    @Attribute var xmlns: String
    @Element var package: Package

    init(xmlns: String, package: MSIBundler.WXSFile.Package) {
      self._xmlns = Attribute(xmlns)
      self._package = Element(package)
    }

    enum CodingKeys: String, CodingKey {
      case xmlns
      case package = "Package"
    }

    struct Package: Codable {
      @Attribute var language: Language
      @Attribute var manufacturer: String
      @Attribute var name: String
      @Attribute var upgradeCode: String
      @Attribute var version: String

      @Element var majorUpgrade: MajorUpgrade
      @Element var mediaTemplate: MediaTemplate

      @Element var icons: [Icon]
      @Element var properties: [Property]

      @Element var standardDirectories: [StandardDirectory]
      @Element var componentGroups: [ComponentGroup]

      enum CodingKeys: String, CodingKey {
        case language = "Language"
        case manufacturer = "Manufacturer"
        case name = "Name"
        case upgradeCode = "UpgradeCode"
        case version = "Version"
        case majorUpgrade = "MajorUpgrade"
        case mediaTemplate = "MediaTemplate"
        case icons = "Icon"
        case properties = "Property"
        case standardDirectories = "StandardDirectory"
        case componentGroups = "ComponentGroup"
      }

      enum Language: String, Codable {
        case english = "1033"
      }

      init(
        language: Language,
        manufacturer: String,
        name: String,
        upgradeCode: String,
        version: String,
        majorUpgrade: MajorUpgrade,
        mediaTemplate: MediaTemplate,
        icons: [Icon] = [],
        properties: [Property] = [],
        standardDirectories: [StandardDirectory] = [],
        componentGroups: [ComponentGroup] = []
      ) {
        self._language = Attribute(language)
        self._manufacturer = Attribute(manufacturer)
        self._name = Attribute(name)
        self._upgradeCode = Attribute(upgradeCode)
        self._version = Attribute(version)
        self._majorUpgrade = Element(majorUpgrade)
        self._mediaTemplate = Element(mediaTemplate)
        self._icons = Element(icons)
        self._properties = Element(properties)
        self._standardDirectories = Element(standardDirectories)
        self._componentGroups = Element(componentGroups)
      }
    }

    struct MajorUpgrade: Codable {
      @Attribute var downgradeErrorMessage: String

      enum CodingKeys: String, CodingKey {
        case downgradeErrorMessage = "DowngradeErrorMessage"
      }

      init(downgradeErrorMessage: String) {
        self._downgradeErrorMessage = Attribute(downgradeErrorMessage)
      }
    }

    struct MediaTemplate: Codable {
      @Attribute var embedCab: YesOrNo

      enum CodingKeys: String, CodingKey {
        case embedCab = "EmbedCab"
      }

      init(embedCab: MSIBundler.WXSFile.YesOrNo) {
        self._embedCab = Attribute(embedCab)
      }
    }

    struct Icon: Codable {
      @Attribute var id: String
      @Attribute var sourceFile: String

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case sourceFile = "SourceFile"
      }

      init(id: String, sourceFile: String) {
        self._id = Attribute(id)
        self._sourceFile = Attribute(sourceFile)
      }
    }

    struct Property: Codable {
      @Attribute var id: String
      @Attribute var value: String

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case value = "Value"
      }

      init(id: String, value: String) {
        self._id = Attribute(id)
        self._value = Attribute(value)
      }
    }

    struct StandardDirectory: Codable {
      @Attribute var id: String
      @Element var directories: [Directory]

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case directories = "Directory"
      }

      init(id: String, directories: [Directory]) {
        self._id = Attribute(id)
        self._directories = Element(directories)
      }
    }

    struct Directory: Codable {
      @Attribute var id: String?
      @Attribute var name: String
      @Element var directories: [Directory]
      @Element var files: [File]

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case directories = "Directory"
        case files = "File"
      }

      init(
        id: String? = nil,
        name: String,
        directories: [Directory] = [],
        files: [File] = []
      ) {
        self._id = Attribute(id)
        self._name = Attribute(name)
        self._directories = Element(directories)
        self._files = Element(files)
      }

      func renamed(to newName: String) -> Self {
        var directory = self
        directory.name = newName
        return directory
      }
    }

    struct ComponentGroup: Codable {
      @Attribute var id: String
      @Attribute var directory: String
      @Element var components: [Component]

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case directory = "Directory"
        case components = "Component"
      }

      init(id: String, directory: String, components: [Component]) {
        self._id = Attribute(id)
        self._directory = Attribute(directory)
        self._components = Element(components)
      }
    }

    struct Component: Codable {
      @Attribute var id: String
      @Element var files: [File]
      @Element var shortcuts: [Shortcut]
      @Element var folderRemovals: [RemoveFolder]
      @Element var registryValues: [RegistryValue]

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case files = "File"
        case shortcuts = "Shortcut"
        case folderRemovals = "RemoveFolder"
        case registryValues = "RegistryValue"
      }

      init(
        id: String,
        files: [File] = [],
        shortcuts: [Shortcut] = [],
        folderRemovals: [RemoveFolder] = [],
        registryValues: [RegistryValue] = []
      ) {
        self._id = Attribute(id)
        self._files = Element(files)
        self._shortcuts = Element(shortcuts)
        self._folderRemovals = Element(folderRemovals)
        self._registryValues = Element(registryValues)
      }
    }

    struct RemoveFolder: Codable {
      @Attribute var id: String
      @Attribute var directory: String?
      @Attribute var on: String

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case directory = "Directory"
        case on = "On"
      }

      init(id: String, directory: String? = nil, on: String) {
        self._id = Attribute(id)
        self._directory = Attribute(directory)
        self._on = Attribute(on)
      }
    }

    struct File: Codable {
      @Attribute var id: String?
      @Attribute var source: String

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case source = "Source"
      }

      init(id: String? = nil, source: String) {
        self._id = Attribute(id)
        self._source = Attribute(source)
      }
    }

    struct Shortcut: Codable {
      @Attribute var id: String
      @Attribute var directory: String
      @Attribute var advertise: YesOrNo
      @Attribute var name: String
      @Attribute var description: String
      @Attribute var target: String
      @Attribute var workingDirectory: String?
      @Attribute var arguments: String?

      enum CodingKeys: String, CodingKey {
        case id = "Id"
        case directory = "Directory"
        case advertise = "Advertise"
        case name = "Name"
        case description = "Description"
        case target = "Target"
        case workingDirectory = "WorkingDirectory"
        case arguments = "Arguments"
      }

      init(
        id: String,
        directory: String,
        advertise: MSIBundler.WXSFile.YesOrNo,
        name: String,
        description: String,
        target: String,
        workingDirectory: String? = nil,
        arguments: String? = nil
      ) {
        self._id = Attribute(id)
        self._directory = Attribute(directory)
        self._advertise = Attribute(advertise)
        self._name = Attribute(name)
        self._description = Attribute(description)
        self._target = Attribute(target)
        self._workingDirectory = Attribute(workingDirectory)
        self._arguments = Attribute(arguments)
      }
    }

    struct RegistryValue: Codable {
      @Attribute var root: String
      @Attribute var key: String
      @Attribute var name: String
      @Attribute var type: String
      @Attribute var value: String
      @Attribute var keyPath: YesOrNo

      enum CodingKeys: String, CodingKey {
        case root = "Root"
        case key = "Key"
        case name = "Name"
        case type = "Type"
        case value = "Value"
        case keyPath = "KeyPath"
      }

      init(
        root: String,
        key: String,
        name: String,
        type: String,
        value: String,
        keyPath: YesOrNo
      ) {
        self._root = Attribute(root)
        self._key = Attribute(key)
        self._name = Attribute(name)
        self._type = Attribute(type)
        self._value = Attribute(value)
        self._keyPath = Attribute(keyPath)
      }
    }

    enum YesOrNo: String, Codable {
      case yes
      case no
    }
  }
}
