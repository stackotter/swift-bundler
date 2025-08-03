import Foundation

/// Evaluates a configuration's overlays and performs any other useful
/// transformations or validations at the same time.
enum ConfigurationFlattener {
  struct Context {
    var platform: Platform
    var bundler: BundlerChoice
    var codingPath = CodingPath()

    func appendingCodingKey(_ key: any CodingKey) -> Self {
      var copy = self
      copy.codingPath.keys.append(key)
      return copy
    }

    func appendingCodingKey(_ key: String) -> Self {
      appendingCodingKey(StringCodingKey(key))
    }

    func appendingCodingIndex(_ index: Int) -> Self {
      appendingCodingKey(CodingIndex(index))
    }
  }

  static func flatten(
    _ configuration: PackageConfiguration,
    with context: Context
  ) throws(Error) -> PackageConfiguration.Flat {
    let flattenedApps = try configuration.apps.mapValues { (name, app) throws(Error) in
      try flatten(
        app,
        with:
          context
          .appendingCodingKey(PackageConfiguration.CodingKeys.apps)
          .appendingCodingKey(name)
      )
    }

    let flattenedProjects = try configuration.projects?.mapValues { (name, project) throws(Error) in
      try flatten(
        project,
        named: name,
        with:
          context
          .appendingCodingKey(PackageConfiguration.CodingKeys.projects)
          .appendingCodingKey(name)
      )
    } ?? [:]

    return PackageConfiguration.Flat(
      formatVersion: configuration.formatVersion,
      apps: flattenedApps,
      projects: flattenedProjects
    )
  }

  static func mergeOverlays<Overlay: ConfigurationOverlay>(
    _ overlays: [Overlay],
    into base: Overlay.Base,
    with context: Context
  ) throws(Error) -> Overlay.Base {
    // Ensure the conditions are met for all present properties
    for overlay in overlays {
      for (exclusiveCondition, properties) in Overlay.exclusiveProperties {
        guard exclusiveCondition != overlay.condition else {
          continue
        }

        let illegalProperties = properties.propertiesPresent(in: overlay)
        guard illegalProperties.isEmpty else {
          let message = ErrorMessage.conditionNotMetForProperties(
            exclusiveCondition,
            properties: illegalProperties
          )
          throw Error(message)
        }
      }
    }

    // Merge overlays into base
    return overlays.filter { (overlay: Overlay) in
      condition(overlay.condition, matches: context)
    }.reduce(into: base) { partialResult, overlay in
      overlay.merge(into: &partialResult)
    }
  }

  static func flatten(
    _ configuration: AppConfiguration,
    with context: Context
  ) throws(Error) -> AppConfiguration.Flat {
    let configuration = try mergeOverlays(
      configuration.overlays ?? [],
      into: configuration,
      with: context
    )

    let invalidRequirement = configuration.rpmRequirements.first { requirement in
      !RPMBundler.isValidRequirement(requirement)
    }
    if let invalidRequirement {
      throw Error(.invalidRPMRequirement(invalidRequirement))
    }

    return AppConfiguration.Flat(
      identifier: configuration.identifier,
      product: configuration.product,
      version: configuration.version,
      appDescription: configuration.appDescription,
      license: configuration.license,
      category: configuration.category,
      icon: configuration.icon,
      urlSchemes: configuration.urlSchemes ?? [],
      plist: configuration.plist ?? [:],
      metadata: configuration.metadata ?? [:],
      dependencies: configuration.dependencies ?? [],
      dbusActivatable: configuration.dbusActivatable,
      rpmRequirements: configuration.rpmRequirements
    )
  }

  static func condition(
    _ condition: OverlayCondition,
    matches context: Context
  ) -> Bool {
    switch condition {
      case .platform(let identifier):
        identifier == context.platform.rawValue
      case .bundler(let identifier):
        identifier == context.bundler.rawValue
    }
  }

  static func flatten(
    _ configuration: ProjectConfiguration,
    named name: String,
    with context: Context
  ) throws(Error) -> ProjectConfiguration.Flat {
    guard name != ProjectConfiguration.rootProjectName else {
      throw Error(.reservedProjectName(name))
    }

    guard configuration.builder.name.hasSuffix(".swift") else {
      throw Error(.projectBuilderNotASwiftFile(configuration.builder.name))
    }

    let mergedConfiguration = try mergeOverlays(
      configuration.overlays ?? [],
      into: configuration,
      with: context
    )

    let source = try Error.catch {
      try mergedConfiguration.source.flatten(
        withRevision: mergedConfiguration.revision,
        revisionField: context.codingPath.appendingKey(
          ProjectConfiguration.CodingKeys.revision
        )
      )
    }

    let builder = try Error.catch {
      let path = context.codingPath.appendingKey(ProjectConfiguration.CodingKeys.builder)
      return try mergedConfiguration.builder.flatten(at: path)
    }

    let products = try mergedConfiguration.products.mapValues { name, product throws(Error) in
      try mergeOverlays(
        product.overlays,
        into: product.flatten(),
        with: context.appendingCodingKey(name)
      )
    }

    return ProjectConfiguration.Flat(
      source: source,
      builder: builder,
      products: products
    )
  }
}
