import Version

extension Version {
  /// A representation of the version using underscore separators and only including down to the least
  /// significant non-zero component.
  ///
  /// For example, `0.5.0` becomes `0_5` and `1.5.2` becomes `1_5_2`.
  var underscoredMinimal: String {
    var string = "\(major)"
    if minor != 0 {
      string += "_\(minor)"
      if patch != 0 {
        string += "_\(patch)"
      }
    }
    return string
  }
}
