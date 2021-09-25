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
  private static let width: CGFloat = 600
  private static let progressPadding: CGFloat = 12
  private static let margin: CGFloat = 16

  private var window: NSWindow

  // Configuration
  var maxProgress: Double = 100
  var jobTitle = ""
  var job: (
    _ setMessage: @escaping (_ string: String) -> Void,
    _ setProgress: @escaping (_ progress: Double) -> Void
  ) -> Void = { _, _ in }

  override init() {
    window = NSWindow(
      contentRect: NSMakeRect(0, 0, Self.width, 200),
      styleMask: [.titled],
      backing: .buffered,
      defer: false,
      screen: nil)

    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let screenWithMouse = (NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })!
    let delegate = WindowDelegate()
    window.delegate = delegate
    window.makeKeyAndOrderFront(nil)
    window.level = .statusBar
    window.setFrameTopLeftPoint(NSPoint(
      x: screenWithMouse.frame.minX + screenWithMouse.frame.width - Self.width - Self.margin,
      y: screenWithMouse.frame.minY + screenWithMouse.frame.height - Self.margin))
    
    let progressBar = NSProgressIndicator(frame: NSMakeRect(
      Self.progressPadding,
      Self.progressPadding,
      Self.width - Self.progressPadding * 2,
      8))
    progressBar.maxValue = maxProgress
    progressBar.isIndeterminate = false
    progressBar.style = .bar
    window.contentView?.addSubview(progressBar)

    NSLayoutConstraint.activate([
      progressBar.topAnchor.constraint(
        equalTo: window.contentView!.topAnchor, 
        constant: Self.progressPadding
      ),
      progressBar.leadingAnchor.constraint(
        equalTo: window.contentView!.leadingAnchor,
        constant: Self.progressPadding
      ),
      progressBar.trailingAnchor.constraint(
        equalTo: window.contentView!.trailingAnchor,
        constant: -Self.progressPadding
      ),
      progressBar.bottomAnchor.constraint(
        equalTo: window.contentView!.bottomAnchor,
        constant: Self.progressPadding
      )
    ])

    DispatchQueue(label: "background").async {
      self.job({ string in
        DispatchQueue.main.async {
          // Leading spaces make it look better when it overflows. The trailing spaces make sure it's still centred
          self.window.title = "   \(self.jobTitle): \(string)   "
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
    _ setMessage: @escaping (_ string: String) -> Void,
    _ setProgress: @escaping (_ progress: Double) -> Void
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