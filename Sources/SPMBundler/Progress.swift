import Foundation
import AppKit

let app = NSApplication.shared

class WindowDelegate: NSObject, NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    terminate("Job cancelled")
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    terminate("Job cancelled")
  }
}

class ProgressDelegate: NSObject, NSApplicationDelegate {
  let window = NSWindow(
    contentRect: NSMakeRect(0, 0, 400, 200),
    styleMask: [.titled],
    backing: .buffered,
    defer: false,
    screen: nil)

  var jobTitle = ""
  var job: (
    _ setMessage: (_ string: String) -> Void,
    _ setProgress: (_ progress: Double) -> Void
  ) -> Void = { _, _ in }

  var maxProgress: Double = 100

  func applicationDidFinishLaunching(_ notification: Notification) {
    let delegate = WindowDelegate()
    window.delegate = delegate
    window.makeKeyAndOrderFront(nil)
    
    let progressBar = NSProgressIndicator(frame: NSMakeRect(16, 16, 368, 8))
    progressBar.maxValue = maxProgress
    progressBar.isIndeterminate = false
    progressBar.style = .bar
    window.contentView?.addSubview(progressBar)

    NSLayoutConstraint.activate([
      progressBar.topAnchor.constraint(
        equalTo: window.contentView!.topAnchor, 
        constant: 16
      ),
      progressBar.leadingAnchor.constraint(
        equalTo: window.contentView!.leadingAnchor,
        constant: 16
      ),
      progressBar.trailingAnchor.constraint(
        equalTo: window.contentView!.trailingAnchor,
        constant: -16
      ),
      progressBar.bottomAnchor.constraint(
        equalTo: window.contentView!.bottomAnchor,
        constant: 16
      )
    ])

    DispatchQueue(label: "background").async {
      self.job({ string in
        DispatchQueue.main.async {
          // textView.string = string
          self.window.title = "\(self.jobTitle): \(string)"
        }
      }, { progress in
        DispatchQueue.main.async {
          progressBar.doubleValue = progress
        }
      })
      
      app.terminate(self)
    }
  }
}

func runProgressJob(
  _ job: @escaping (
    _ setMessage: (_ string: String) -> Void,
    _ setProgress: (_ progress: Double) -> Void
  ) -> Void,
  title: String,
  maxProgress: Double
) {
  let delegate = ProgressDelegate()
  delegate.job = job
  delegate.jobTitle = title
  delegate.maxProgress = maxProgress

  app.delegate = delegate
  app.run()
}