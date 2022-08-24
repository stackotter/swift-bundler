extension PackageConfiguration {
  enum MigrationMode: Equatable {
    case readOnly
    case writeChanges(backup: Bool)
  }
}
