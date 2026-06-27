import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
  var onWindowChange: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async { onWindowChange(view.window) }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async { onWindowChange(nsView.window) }
  }
}

enum AppAlert {
  static func show(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
  }
}
