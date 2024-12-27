import Foundation

/// Inserts metadata into executable files.
///
/// Swift Bundler inserts metadata at the end of your main executable file
/// after compilation. The format is intended to be simple and portable to
/// ensure that even if someone isn't using the Swift Bundler runtime they
/// can easily parse the metadata at runtime. If the metadata format ever
/// gets extended, it will be extended in such a way that current metadata
/// remains valid, and future metadata is backwards compatible.
enum MetadataInserter {
  /// If an executable ends with this string, it probably contains Swift
  /// Bundler metadata.
  static let magicBytes: [UInt8] = Array("SBUNMETA".utf8)

  /// Metadata appended to the end of executable files built with Swift
  /// Bundler.
  struct Metadata: Codable {
    /// The app's identifier.
    var appIdentifier: String
    /// The app's version.
    var appVersion: String
    /// Additional user-defined metadata.
    var additionalMetadata: [String: MetadataValue]
  }

  /// Generates an app's metadata from its configuration.
  static func metadata(for configuration: AppConfiguration.Flat) -> Metadata {
    Metadata(
      appIdentifier: configuration.identifier,
      appVersion: configuration.version,
      additionalMetadata: configuration.metadata
    )
  }

  /// Inserts metadata at the end of the given executable file.
  static func insert(
    _ metadata: Metadata,
    into executableFile: URL
  ) -> Result<(), MetadataInserterError> {
    Data.read(from: executableFile)
      .mapError { error in
        .failedToReadExecutableFile(executableFile, error)
      }
      .andThen { data in
        JSONEncoder().encode(metadata)
          .mapError { error in
            .failedToEncodeMetadata(error)
          }
          .map { encodedMetadata in
            var data = data

            // A tag representing the type of the next metadata entry. For now
            // it's just '0' meaning 'end'. This is purely to allow for the
            // format to be extended in the future (e.g. to include resources).
            // We could of course just keep adding more entries to the JSON,
            // but certain types of data just don't work well with JSON (e.g.
            // large amounts of binary data).
            //
            // For forwards compatibility, do NOT require this value to be one
            // you support. Simply stop parsing if you don't understand it.
            writeBigEndianUInt64(0, to: &data)

            // The default JSON metadata entry. For now this is the only type
            // of metadata entry. It would be suffixed with a tag type, however
            // this is guaranteed to always be the first entry (for backwards
            // compatibility), and I want to bake that into the format.
            data.append(contentsOf: encodedMetadata)
            // The data's length in bytes.
            writeBigEndianUInt64(UInt64(encodedMetadata.count), to: &data)

            // Magic bytes so that apps (and external tools) can know if they
            // contain any Swift Bundler metadata. Since it's technically
            // possible for false positives to occur, apps and tools should
            // always fail safely if the metadata is malformed.
            data.append(contentsOf: magicBytes)

            return data
          }
      }
      .andThen { (modifiedData: Data) in
        modifiedData.write(to: executableFile)
          .mapError { error in
            .failedToWriteExecutableFile(executableFile, error)
          }
      }
  }

  /// Writes a single UInt64 value to the end of a data buffer (in big endian
  /// order).
  private static func writeBigEndianUInt64(_ value: UInt64, to data: inout Data) {
    let count = MemoryLayout<UInt64>.size
    withUnsafePointer(to: value.bigEndian) { pointer in
      pointer.withMemoryRebound(to: UInt8.self, capacity: count) { pointer in
        data.append(pointer, count: count)
      }
    }
  }
}
