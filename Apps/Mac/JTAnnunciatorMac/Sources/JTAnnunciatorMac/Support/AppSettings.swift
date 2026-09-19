import Foundation
import JTAnnunciatorCore

/// `UserDefaults`-backed persistence for this app's settings, same pattern FTX1Remote's own
/// `AppearanceSettings`/`StationSettings` use. Mac-only (this target), unlike those — nothing
/// here needs to be shared with another app target.
enum AppSettings {
    private enum Key {
        static let wantedList = "com.jtannunciator.wantedList"
        static let ctyDatPath = "com.jtannunciator.ctyDatPath"
        static let udpPort = "com.jtannunciator.udpPort"
        static let alertSoundEnabled = "com.jtannunciator.alertSoundEnabled"
    }

    static func loadWantedList() -> WantedList? {
        guard let data = UserDefaults.standard.data(forKey: Key.wantedList) else { return nil }
        return try? JSONDecoder().decode(WantedList.self, from: data)
    }

    static func saveWantedList(_ list: WantedList) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: Key.wantedList)
    }

    /// The user-supplied cty.dat file location (see `CTYDatParser`'s doc comment for why this
    /// app doesn't ship one of its own). `nil` until the user picks one in Settings.
    static var ctyDatPath: String? {
        get { UserDefaults.standard.string(forKey: Key.ctyDatPath) }
        set { UserDefaults.standard.set(newValue, forKey: Key.ctyDatPath) }
    }

    static var udpPort: UInt16 {
        get {
            let stored = UserDefaults.standard.integer(forKey: Key.udpPort)
            return stored > 0 && stored <= UInt16.max ? UInt16(stored) : 2237
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: Key.udpPort) }
    }

    static var alertSoundEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: Key.alertSoundEnabled) as? Bool ?? true
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.alertSoundEnabled) }
    }
}
