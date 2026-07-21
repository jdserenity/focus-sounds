import AppKit
import Carbon.HIToolbox
import FocusSoundsCore
import Foundation

@MainActor
final class GlobalHotkeyController {
  private static let hotKeySignature: OSType = 0x4643_5348 // FCSH
  private static let hotKeyID: UInt32 = 1

  private var hotKeyRef: EventHotKeyRef?
  private var installedHandler = false
  var onTrigger: (() -> Void)?

  func apply(_ hotkey: GlobalHotkey) {
    unregister()
    guard hotkey.isValid else { return }
    installHandlerIfNeeded()
    var ref: EventHotKeyRef?
    let status = RegisterEventHotKey(
      UInt32(hotkey.keyCode),
      hotkey.carbonModifiers,
      EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyID),
      GetApplicationEventTarget(),
      0,
      &ref
    )
    guard status == noErr else { return }
    hotKeyRef = ref
  }

  func unregister() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
  }

  private func installHandlerIfNeeded() {
    guard !installedHandler else { return }
    installedHandler = true
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let selfPtr = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData -> OSStatus in
        guard let userData, let event else { return noErr }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )
        guard status == noErr,
              hotKeyID.signature == GlobalHotkeyController.hotKeySignature,
              hotKeyID.id == GlobalHotkeyController.hotKeyID else { return noErr }
        let controller = Unmanaged<GlobalHotkeyController>.fromOpaque(userData).takeUnretainedValue()
        Task { @MainActor in controller.onTrigger?() }
        return noErr
      },
      1,
      &eventType,
      selfPtr,
      nil
    )
  }
}

@MainActor
final class HotkeyCaptureSession {
  private var monitor: Any?

  func start(onCapture: @escaping (GlobalHotkey) -> Void, onCancel: @escaping () -> Void) {
    stop()
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
      if event.keyCode == 53 {
        onCancel()
        return nil
      }
      let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
      let carbon = Self.carbonModifiers(from: flags)
      guard let hotkey = GlobalHotkey.from(eventKeyCode: event.keyCode, carbonModifiers: carbon) else {
        return event
      }
      onCapture(hotkey)
      return nil
    }
  }

  func stop() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }

  private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var carbon: UInt32 = 0
    if flags.contains(.command) { carbon |= UInt32(cmdKey) }
    if flags.contains(.option) { carbon |= UInt32(optionKey) }
    if flags.contains(.control) { carbon |= UInt32(controlKey) }
    if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
    return carbon
  }
}
