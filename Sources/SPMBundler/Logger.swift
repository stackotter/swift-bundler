import DeltaLogger
import Logging

var log = Logger(label: "Bundler") { label in
  return DeltaLogHandler(label: label)
}