import Crypto
import Foundation

extension MSIBundler {
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
}
