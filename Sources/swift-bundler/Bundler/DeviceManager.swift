import Foundation

enum DeviceManager {
  enum Error: LocalizedError {
    case deviceNotFound(specifier: String, platform: Platform?)
    case failedToListXcodeDestinations(ProcessError)
    case failedToCreateDummyProject(Swift.Error)
    case failedToParseXcodeDestinationList(
      _ xcodeDestinationList: String,
      reason: String
    )
    case failedToParseXcodeDestination(
      _ xcodeDestination: String,
      reason: String
    )

    var errorDescription: String? {
      switch self {
        case .deviceNotFound(let specifier, .none):
          return "Device not found for device specifier '\(specifier)'"
        case .deviceNotFound(let specifier, .some(let platform)):
          return """
            Device not found for device specifier '\(specifier)' with platform \
            '\(platform)'
            """
        case .failedToCreateDummyProject(let error):
          return """
            Failed to create dummy project required to list Xcode destinations: \
            \(error.localizedDescription)
            """
        case .failedToListXcodeDestinations(let error):
          return "Failed to list Xcode destinations: \(error.localizedDescription)"
        case .failedToParseXcodeDestinationList(_, let reason):
          return "Failed to parse Xcode destination list: \(reason)"
        case .failedToParseXcodeDestination(_, let reason):
          return "Failed to parse Xcode destination: \(reason)"
      }
    }
  }

  /// Only works on macOS.
  static func listDestinations() -> Result<[Device], Error> {
    let dummyProject =
      FileManager.default.temporaryDirectory
      / "dev.stackotter.swift-bundler/SwiftBundlerDummyPackage"
    let dummyProjectName = "Dummy"

    return Result.success().andThen(if: !dummyProject.exists()) { _ in
      FileManager.default.createDirectory(at: dummyProject)
        .mapError(Error.failedToCreateDummyProject)
        .andThen { _ in
          SwiftPackageManager.createPackage(
            in: dummyProject,
            name: dummyProjectName
          )
          .mapError(Error.failedToCreateDummyProject)
        }
    }.andThen { _ in
      Process.create(
        "xcodebuild",
        arguments: [
          "-showdestinations", "-scheme", dummyProjectName,
        ],
        directory: dummyProject
      ).getOutput().mapError(Error.failedToListXcodeDestinations)
    }.andThen { output in
      let lines = output.split(
        separator: "\n",
        omittingEmptySubsequences: false
      ).map(String.init)

      guard
        let startIndex =
          lines.firstIndex(
            of: "\tAvailable destinations for the \"\(dummyProjectName)\" scheme:"
          )?.advanced(by: 1),
        let endIndex = lines[startIndex...].firstIndex(of: "")
      else {
        return .failure(
          .failedToParseXcodeDestinationList(
            output,
            reason: "Couldn't locate destination section in output"
          )
        )
      }

      return Array(lines[startIndex..<endIndex])
        .tryMap(parseXcodeDestination)
        .map { devices in
          devices.compactMap { $0 }
        }
    }
  }

  /// Returns nil if the line represents a device that Swift Bundler doesn't
  /// support.
  private static func parseXcodeDestination(
    _ line: String
  ) -> Result<Device?, Error> {
    var index = line.startIndex
    var dictionary: [String: String] = [:]

    while index < line.endIndex, line[index].isWhitespace {
      index = line.index(after: index)
      continue
    }

    func failure<R>(_ reason: String) -> Result<R, Error> {
      .failure(.failedToParseXcodeDestination(line, reason: reason))
    }

    func read(_ count: Int) -> String? {
      let endIndex = line.index(index, offsetBy: count)
      if endIndex <= line.endIndex {
        let result = String(line[index..<endIndex])
        index = endIndex
        return result
      } else {
        return nil
      }
    }

    func readUntil(oneOf characters: Set<Character>) -> Result<String, Error> {
      var endIndex = index
      while endIndex != line.endIndex, !characters.contains(line[endIndex]) {
        endIndex = line.index(after: endIndex)
      }

      guard endIndex != line.endIndex else {
        let characterList = characters.map { "'\($0)'" }.joined(separator: ", ")
        return failure(
          "Expected to encounter one of [\(characterList)] but got end of line"
        )
      }

      let startIndex = index
      index = endIndex
      return .success(String(line[startIndex..<endIndex]))
    }

    func expect(_ pattern: String) -> Result<(), Error> {
      let startIndex = index
      guard let slice = read(pattern.count) else {
        return failure(
          """
          Expected '\(pattern)' at index \(startIndex.offset(in: line)), but \
          got end of line
          """
        )
      }
      guard pattern == slice else {
        return failure(
          """
          Expected '\(pattern)' at index \(startIndex.offset(in: line)), but \
          got '\(slice)'
          """
        )
      }
      return .success()
    }

    return expect("{ ")
      .andThen { _ -> Result<[String: String], Error> in
        while line[index] != "}" {
          let result = readUntil(oneOf: [":"])
            .andThenDoSideEffect { _ in
              expect(":")
            }.andThen { key in
              readUntil(oneOf: ["[", ",", "}"])
                .andThen(if: line[index] == "[") { value in
                  // We have to handle a horrid edge case because one of the Mac
                  // targets usually has the 'variant' field set to
                  // 'Designed for [iPad, iPhone]', which contains a comma and
                  // messes everything up. We could technically make a smarter
                  // parser that can handle that specific case without making it
                  // an edge case, but given that this format isn't even a proper
                  // data format, Apple's probably always gonna cook up a few more
                  // edge cases, so I don't think it'd be worth it.
                  readUntil(oneOf: ["]"])
                    .andThen { bracketedContent in
                      readUntil(oneOf: [",", "}"]).map { trailingContent in
                        value + bracketedContent + trailingContent
                      }
                    }
                }
                .map { value in
                  if line[index] == "}" {
                    // Remove trailing space
                    (key, String(value.dropLast()))
                  } else {
                    (key, value)
                  }
                }
            }.ifSuccess { _ in
              // Skip space between each key-value pair
              if index < line.endIndex, line[index] == "," {
                index = line.index(index, offsetBy: 2)
              }
            }

          switch result {
            case .success((let key, let value)):
              dictionary[key] = value
            case .failure(let error):
              return .failure(error)
          }
        }

        return expect("}").replacingSuccessValue(with: dictionary)
      }
      .andThen { dictionary in
        guard let platform = dictionary["platform"] else {
          return failure("Missing platform")
        }

        guard let parsedPlatform = ApplePlatform.parseXcodeDestinationName(platform) else {
          // Skip devices for platforms that we don't handle, such as DriverKit
          return .success(nil)
        }

        guard let id = dictionary["id"] else {
          // Skip generic destinations without ids
          return .success(nil)
        }

        guard !id.hasSuffix(":placeholder") else {
          // Skip generic destinations with ids
          return .success(nil)
        }

        guard let name = dictionary["name"] else {
          return failure("Missing name")
        }

        let device = Device(
          applePlatform: parsedPlatform,
          name: name,
          id: id,
          status: dictionary["error"].map(ConnectedDevice.Status.unavailable)
            ?? .available
        )
        return .success(device)
      }
  }

  static func resolve(
    specifier: String,
    platform: Platform?
  ) -> Result<Device, Error> {
    guard specifier != "host" else {
      if platform == nil || platform == HostPlatform.hostPlatform.platform {
        return .success(.host(HostPlatform.hostPlatform))
      } else {
        return .failure(.deviceNotFound(specifier: specifier, platform: platform))
      }
    }

    guard HostPlatform.hostPlatform == .macOS else {
      return .failure(.deviceNotFound(specifier: specifier, platform: platform))
    }

    return listDestinations().map { devices in
      devices.sorted { first, second in
        // Physical devices first (since --simulator can be used to
        // disambiguate simulators) and put shorter names first (otherwise
        // there'd be no guarantee the "iPhone 15" matches "iPhone 15" when
        // both "iPhone 15" and "iPhone 15 Pro" exist, and you'd be left with
        // no way to disambiguate). Also put available devices above
        // unavailable ones.
        switch (first, second) {
          case (.host, .connected):
            return false
          case (.connected(let first), .connected(let second)):
            if first.platform.isSimulator && !second.platform.isSimulator {
              return false
            } else if first.name.count > second.name.count {
              return false
            } else if second.status == .available && first.status != .available {
              return false
            } else {
              return true
            }
          default:
            return true
        }
      }
    }.andThen { devices in
      if let device = devices.first(where: { $0.id == specifier }) {
        guard platform == nil || device.platform == platform else {
          return .failure(.deviceNotFound(specifier: specifier, platform: platform))
        }
        return .success(device)
      }

      let matches = devices.filter { device in
        // Filter by platform if provided
        if let platform = platform {
          return device.platform == platform
        } else {
          return true
        }
      }.filter { device in
        device.description.contains(specifier)
      }

      guard let match = matches.first else {
        return .failure(.deviceNotFound(specifier: specifier, platform: platform))
      }

      if matches.count > 1 {
        log.warning(
          "Multiple devices matched '\(specifier)', using \(match.description)"
        )
      }

      return .success(match)
    }
  }
}
