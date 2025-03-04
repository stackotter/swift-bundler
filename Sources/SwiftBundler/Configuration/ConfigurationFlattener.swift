import Foundation

/// Evaluates a configuration's overlays and performs any other useful
/// transformations or validations at the same time.
enum ConfigurationFlattener {
  struct Context {
    var platform: Platform
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
  ) -> Result<PackageConfiguration.Flat, Error> {
    Array(configuration.apps)
      .tryMap { (name, appConfiguration) in
        flatten(
          appConfiguration,
          with:
            context
            .appendingCodingKey(PackageConfiguration.CodingKeys.apps)
            .appendingCodingKey(name)
        ).map { app in
          (name, app)
        }
      }
      .andThen { flattenedApps in
        Array(configuration.projects ?? [:]).tryMap { (name, projectConfiguration) in
          flatten(
            projectConfiguration,
            named: name,
            with:
              context
              .appendingCodingKey(PackageConfiguration.CodingKeys.projects)
              .appendingCodingKey(name)
          ).map { project in
            (name, project)
          }
        }
        .map { flattenedProjects in
          (flattenedApps, flattenedProjects)
        }
      }
      .map { (flattenedApps, flattenedProjects) in
        PackageConfiguration.Flat(
          formatVersion: configuration.formatVersion,
          apps: Dictionary(flattenedApps) { first, _ in first },
          projects: Dictionary(flattenedProjects) { first, _ in first }
        )
      }
  }

  static func mergeOverlays<Overlay: ConfigurationOverlay>(
    _ overlays: [Overlay],
    into base: Overlay.Base,
    with context: Context
  ) -> Result<Overlay.Base, Error> {
    overlays.tryMap { overlay in
      // Ensure the conditions are met for all present properties
      Array(Overlay.exclusiveProperties)
        .tryForEach { (exclusiveCondition, properties) in
          guard exclusiveCondition != overlay.condition else {
            return .success()
          }

          let illegalProperties = properties.propertiesPresent(in: overlay)
          guard illegalProperties.isEmpty else {
            return .failure(
              .conditionNotMetForProperties(
                exclusiveCondition,
                properties: illegalProperties
              )
            )
          }

          return .success()
        }
        .replacingSuccessValue(with: overlay)
    }.map { overlays in
      // Merge overlays into base
      overlays.filter { (overlay: Overlay) in
        condition(overlay.condition, matches: context)
      }.reduce(into: base) { partialResult, overlay in
        overlay.merge(into: &partialResult)
      }
    }
  }

  static func flatten(
    _ configuration: AppConfiguration,
    with context: Context
  ) -> Result<AppConfiguration.Flat, Error> {
    mergeOverlays(
      configuration.overlays ?? [],
      into: configuration,
      with: context
    ).map { configuration in
      AppConfiguration.Flat(
        identifier: configuration.identifier,
        product: configuration.product,
        version: configuration.version,
        category: configuration.category,
        icon: configuration.icon,
        urlSchemes: configuration.urlSchemes ?? [],
        plist: configuration.plist ?? [:],
        metadata: configuration.metadata ?? [:],
        dependencies: configuration.dependencies ?? [],
        dbusActivatable: configuration.dbusActivatable
      )
    }
  }

  static func condition(
    _ condition: OverlayCondition,
    matches context: Context
  ) -> Bool {
    switch condition {
      case .platform(let identifier):
        identifier == context.platform.rawValue
    }
  }

  static func flatten(
    _ configuration: ProjectConfiguration,
    named name: String,
    with context: Context
  ) -> Result<ProjectConfiguration.Flat, Error> {
    guard configuration.builder.name.hasSuffix(".swift") else {
      return .failure(
        Error.projectBuilderNotASwiftFile(
          configuration.builder.name
        )
      )
    }

    return mergeOverlays(
      configuration.overlays ?? [],
      into: configuration,
      with: context
    ).andThen { mergedConfiguration in
      let source: ProjectConfiguration.Source.Flat
      switch mergedConfiguration.source.flatten(
        withRevision: mergedConfiguration.revision,
        revisionField: context.codingPath.appendingKey(
          ProjectConfiguration.CodingKeys.revision
        )
      ) {
        case .failure(let error):
          return .failure(.other(error))
        case .success(let value):
          source = value
      }

      let builder: ProjectConfiguration.Builder.Flat
      switch mergedConfiguration.builder.flatten(
        at: context.codingPath.appendingKey(ProjectConfiguration.CodingKeys.builder)
      ) {
        case .failure(let error):
          return .failure(.other(error))
        case .success(let value):
          builder = value
      }

      let products: [String: ProjectConfiguration.Product.Flat]
      switch mergedConfiguration.products.tryMapValues({ name, product in
        mergeOverlays(
          product.overlays,
          into: product.flatten(),
          with: context.appendingCodingKey(name)
        )
      }) {
        case .failure(let error):
          return .failure(.other(error))
        case .success(let value):
          products = value
      }

      let flatConfiguration = ProjectConfiguration.Flat(
        source: source,
        builder: builder,
        products: products
      )
      return .success(flatConfiguration)
    }
  }
}
