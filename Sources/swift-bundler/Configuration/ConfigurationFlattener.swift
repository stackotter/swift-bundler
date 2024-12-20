enum ConfigurationFlattener {
  struct Context {
    var platform: Platform

  }

  static func flatten(
    _ configuration: PackageConfiguration,
    with context: Context
  ) -> Result<PackageConfiguration.Flat, ConfigurationFlattenerError> {
    Array(configuration.apps).tryMap { (name, appConfiguration) in
      flatten(appConfiguration, with: context).map { app in
        (name, app)
      }
    }
    .map { appPairs in
      PackageConfiguration.Flat(
        formatVersion: configuration.formatVersion,
        apps: Dictionary(appPairs) { first, _ in first }
      )
    }
  }

  static func flatten(
    _ configuration: AppConfiguration,
    with context: Context
  ) -> Result<AppConfiguration.Flat, ConfigurationFlattenerError> {
    let base = AppConfiguration.Flat(
      identifier: configuration.identifier,
      product: configuration.product,
      version: configuration.version,
      category: configuration.category,
      icon: configuration.icon,
      urlSchemes: configuration.urlSchemes ?? [],
      plist: configuration.plist ?? [:],
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
}
