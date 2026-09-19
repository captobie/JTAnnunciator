import AppKit

/// Plays the alert sound JTAlert-style: a distinct system sound for a fresh wanted station vs.
/// one you've already worked. Deliberately just `NSSound` system sounds for v1, not custom
/// audio files — see the README's scope note for what's deferred (per-category custom sounds,
/// text-to-speech callsign announcements, both real JTAlert features).
enum AlertSoundPlayer {
    static func play(alreadyWorked: Bool) {
        guard AppSettings.alertSoundEnabled else { return }
        let soundName = alreadyWorked ? "Pop" : "Glass"
        NSSound(named: soundName)?.play()
    }
}
