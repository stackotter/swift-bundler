import Foundation

struct RuntimeError: LocalizedError {
  var message: String

  var errorDescription: String? {
    message
  }
}
