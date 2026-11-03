import Foundation

enum AppIdentity {
    // Fork isolation: every per-app folder and keychain service follows the bundle ID,
    // so this build can never reach the data of an installed upstream VoiceInk.
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.jvbrazentide.VoiceInkLocal"
}
