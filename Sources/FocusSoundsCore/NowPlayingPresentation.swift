import Foundation

public enum NowPlayingPresentation: Equatable, Sendable {
  case inactive
  case active(title: String, isPlaying: Bool)
}

public enum NowPlayingPresentationBuilder {
  /// `hasSession` means a sound is loaded (including while paused). Cleared after stop/select.
  public static func make(title: String?, isPlaying: Bool, hasSession: Bool) -> NowPlayingPresentation {
    guard hasSession, let title, !title.isEmpty else { return .inactive }
    return .active(title: title, isPlaying: isPlaying)
  }
}
