import Foundation
import SwiftBacktrace

NSSetUncaughtExceptionHandler { (exception) in
  let stack = exception.callStackReturnAddresses
  print("Stack trace: \(stack)")
}

func handleSignal(_ code: Int32) {
  print("caught crash")
}

signal(SIGABRT, handleSignal);
signal(SIGILL, handleSignal);
signal(SIGSEGV, handleSignal);
signal(SIGFPE, handleSignal);
signal(SIGBUS, handleSignal);
signal(SIGPIPE, handleSignal);

Bundler.main()

// TODO: support sandboxing
// TODO: add proper help messages to subcommands, options and flags
