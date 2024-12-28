import Foundation

/// Evaluates a configuration's overlays and performs any other useful
/// transformations or validations at the same time.
enum ConfigurationFlattener {
  struct Context {
    var platform: Platform
  }

  static func flatten(
    _ configuration: PackageConfiguration,
    with context: Context
  ) -> Result<PackageConfiguration.Flat, Error> {
    Array(configuration.apps).tryMap { (name, appConfiguration) in
      flatten(appConfiguration, with: context).map { app in
        (name, app)
      }
    }
    .andThen { flattenedApps in
      Array(configuration.projects ?? [:]).tryMap { (name, projectConfiguration) in
        flatten(projectConfiguration, with: context).map { project in
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

  static func flatten(
    _ configuration: AppConfiguration,
    with context: Context
  ) -> Result<AppConfiguration.Flat, Error> {
    let base = AppConfiguration.Flat(
      identifier: configuration.identifier,
      product: configuration.product,
      version: configuration.version,
      category: configuration.category,
      icon: configuration.icon,
      urlSchemes: configuration.urlSchemes ?? [],
      plist: configuration.plist ?? [:],
      metadata: configuration.metadata ?? [:],
      dependencies: configuration.dependencies ?? [],
      dbusActivatable: false
    )
    let overlays = configuration.overlays ?? []

    return overlays.tryMap { overlay in
      // Ensure the conditions are met for all present properties
      Array(AppConfiguration.Overlay.exclusiveProperties)
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
      overlays
        .filter { overlay in
          condition(overlay.condition, matches: context)
        }
        .reduce(into: base) { partialResult, overlay in
          func merge<T>(_ current: inout T?, _ overlay: T?) {
            current = overlay ?? current
          }

          func merge<T>(_ current: inout T, _ overlay: T?) {
            current = overlay ?? current
          }

          merge(&partialResult.identifier, overlay.identifier)
          merge(&partialResult.product, overlay.product)
          merge(&partialResult.version, overlay.version)
          merge(&partialResult.category, overlay.category)
          merge(&partialResult.icon, overlay.icon)
          merge(&partialResult.urlSchemes, overlay.urlSchemes)
          merge(&partialResult.plist, overlay.plist)
          merge(&partialResult.metadata, overlay.metadata)
          merge(&partialResult.dependencies, overlay.dependencies)
          merge(&partialResult.dbusActivatable, overlay.dbusActivatable)
        }
    }
  }

  static func condition(
    _ condition: AppConfiguration.Overlay.Condition,
    matches context: Context
  ) -> Bool {
    switch condition {
      case .platform(let identifier):
        identifier == context.platform.rawValue
    }
  }

  static func flatten(
    _ configuration: ProjectConfiguration,
    with context: Context
  ) -> Result<ProjectConfiguration.Flat, Error> {
    guard configuration.builder.name.hasSuffix(".swift") else {
      return .failure(
        Error.projectBuilderNotASwiftFile(
          configuration.builder.name
        )
      )
    }

    let builderAPI: ProjectConfiguration.Source.FlatWithDefaultRepository
    switch configuration.builder.apiSource {
      case .local(let path):
        guard configuration.builder.api == nil else {
          return .failure(
            Error.localBuilderAPIMustNotSpecifyRevision(path)
          )
        }
        builderAPI = .local(path)
      case .git(let url):
        guard let apiRequirement = configuration.builder.api else {
          return .failure(
            Error.gitBasedBuilderAPIMissingAPIRequirement(url)
          )
        }
        builderAPI = .git(url, requirement: apiRequirement)
      case nil:
        guard let apiRequirement = configuration.builder.api else {
          return .failure(
            Error.defaultBuilderAPIMissingAPIRequirement
          )
        }
        builderAPI = .git(nil, requirement: apiRequirement)
    }

    let source: ProjectConfiguration.Source.Flat
    switch configuration.source {
      case .git(let url):
        guard let revision = configuration.revision else {
          return .failure(
            Error.gitSourceMissingRevision(url)
          )
        }
        source = .git(url, requirement: .revision(revision))
      case .local(let path):
        source = .local(path)
    }

    return .success(
      ProjectConfiguration.Flat(
        source: source,
        builder: ProjectConfiguration.Builder.Flat(
          name: configuration.builder.name,
          type: configuration.builder.type,
          api: builderAPI
        ),
        products: configuration.products
      )
    )
  }
}
