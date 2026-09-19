# JTAnnunciator

A native Mac app that listens to [WSJT-X](https://wsjtx.groups.io/g/main)'s UDP protocol and
gives [JTAlert](https://www.dxlabsuite.com/jtalert/)-style visual/audio alerts when a wanted
callsign or wanted DXCC entity is decoded. JTAlert is Windows-only; [JT-Bridge](https://www.qsl.net/on4kjm/JTBridge/index.html),
its closest Mac analogue, doesn't attempt JTAlert's visual approach. This app exists to bring
that specific thing — a genuinely visual, glanceable "hey, THIS station just showed up" alert —
to macOS.

## Status: v1 scaffold, not yet run against real hardware/software

This repo was scaffolded without access to a macOS/Xcode toolchain, so **nothing here has been
built, run, or tested against a live WSJT-X instance yet.** The core protocol/logic layer
(`Sources/JTAnnunciatorCore`) is unit-tested and its tests are believed correct by careful manual
review, but "believed correct by review" is not the same bar as "ran `swift test` and it passed"
— that's the first thing to do once this is opened on an actual Mac. See "First things to verify
on real hardware" below before trusting this for real operating.

## Scope

**v1 is deliberately just:**
- Listening to WSJT-X's UDP broadcast (Heartbeat, Status, Decode, Clear, QSO Logged, Close, WSPR
  Decode, Logged ADIF messages).
- Matching decoded callsigns against a **wanted callsigns** list and a **wanted DXCC entities**
  list.
- A visual "annunciator" banner + color-coded decode list, plus a system alert sound.
- Dimming (not hiding) stations you've already worked this session, tracked from QSO Logged
  messages.

**Deliberately not built yet** (real JTAlert features, genuinely useful, just out of scope for
v1 — see "Possible next steps"):
- Wanted US states/counties, CQ/ITU zones, continents, LoTW/eQSL status.
- Persisting "worked before" across app restarts (v1 only tracks QSOs logged *this session*;
  it doesn't read your ADIF log on startup).
- Sending anything back to WSJT-X (Heartbeat replies to register as a visible UDP client, Reply
  messages to initiate a QSO, Highlight Callsign to mark stations in WSJT-X's own window). This
  app only listens today.
- Per-category custom alert sounds or text-to-speech callsign announcements.
- A real FT8/FT4 message grammar parser (see "Callsign extraction heuristic" below).

## Architecture

- **`Sources/JTAnnunciatorCore/`** — a platform-agnostic Swift package (buildable/testable on
  Linux, no AppKit/SwiftUI/Network.framework dependency), containing everything that doesn't
  need a Mac:
  - `WSJTX/` — `QDataStream.swift` (a reader/writer for Qt's `QDataStream` big-endian wire
    format — the framing every WSJT-X UDP packet uses), `WSJTXMessage.swift` (the message
    types), `WSJTXMessageDecoder.swift` (datagram → `WSJTXMessage`, plus a Heartbeat encoder for
    a future "announce ourselves to WSJT-X" feature).
  - `DXCC/` — `CTYEntry.swift`/`CTYDatParser.swift` (parses the industry-standard `cty.dat` DXCC
    country-file format), `CallsignParser.swift` (portable-suffix handling, e.g. `G4ABC/VP8`).
  - `Alerts/` — `WantedList.swift`, `FT8MessageParser.swift` (pulls candidate callsigns out of a
    decoded message string), `AlertEvent.swift`, `AlertEngine.swift` (the actual matching logic).
- **`Apps/Mac/JTAnnunciatorMac/`** — the Mac app. **A separate Swift package (its own
  `Package.swift`, an executable target), not an Xcode project** — this was scaffolded without
  Xcode available, and hand-authoring a `.xcodeproj`'s `project.pbxproj` reliably without being
  able to open it in Xcode isn't something to do by guesswork. A SwiftUI `App` built as an SPM
  executable target is a real, supported way to ship a Mac app; run it with `swift run` from
  that directory, or open the folder in Xcode (Xcode opens `Package.swift` directly, no
  `.xcodeproj` needed) once you want a proper signed `.app` bundle/icon/entitlements. Converting
  to a full Xcode project later, if wanted, is straightforward — it's a thin SwiftUI layer over
  `JTAnnunciatorCore` with no unusual dependencies.
  - `WSJTXUDPListener.swift` — `Network.framework` (`NWListener`) UDP receiver, Mac-only.
  - `AnnunciatorViewModel.swift` — owns the listener + `AlertEngine`, publishes state for the UI.
  - `Views/` — `AnnunciatorView` (main window: status bar + color-coded decode list + the alert
    banner overlay), `AlertBannerView` (the actual "annunciator"), `WantedListsView`,
    `SettingsView` (UDP port, cty.dat file picker, alert sound toggle).
  - `Support/` — `AppSettings` (`UserDefaults` persistence), `AlertSoundPlayer` (`NSSound`),
    `ColorCoding` (the JTAlert-style visual language: red = wanted callsign, yellow = wanted
    DXCC, dimmed = already worked).

### Why WSJT-X's UDP protocol, not ADIF-tailing or a log-file watcher

WSJT-X pushes every decode over UDP in real time (its own "Status"/"Decode" messages), which is
both lower-latency and far simpler to consume correctly than watching a log file for appended
lines. This is also exactly what JTAlert itself does on Windows, and what basically every other
WSJT-X companion tool (GridTracker, N1MM's WSJT-X bridge, etc.) does. Field layout for the
message types this app uses was taken directly from WSJT-X's own `Network/NetworkMessage.hpp`
(fetched from a public mirror while writing this), not guessed or reconstructed from
third-party tool behavior.

### DXCC data: why this app doesn't ship a cty.dat

`cty.dat` — the DXCC country-file format almost every ham logging program (N1MM, Log4OM, CQRLOG,
...) uses — has real, non-obvious geographic exceptions (sub-entities sharing a prefix, like
Fiji/Conway Reef/Rotuma all under `3D2`; stations physically located somewhere other than their
callsign prefix suggests). Hand-authoring an accurate table without the ability to validate it
against real-world data would be guessing at exactly the kind of detail that matters most for
this feature to be trustworthy. So `CTYDatParser` implements the parser (grounded against real
`cty.dat` excerpts as test fixtures — see `CTYDatParserTests.swift`), and Settings lets you point
it at whichever `cty.dat` you already trust — the same file your logging program uses. Get one
from your logger's install directory, or from [country-files.com](https://www.country-files.com/).

### Callsign extraction heuristic

Rather than implementing WSJT-X's full standard-messages grammar (`CQ <call> <grid>` vs.
`<call1> <call2> <report>` vs. free text, etc.), `FT8MessageParser` scans every whitespace-
separated token in a decoded message and keeps the ones that look like a callsign (rejecting
grid squares, signal reports, and known protocol keywords like `CQ`/`RR73`/`73`). This means
every message shape alerts correctly on any wanted station present in it, at the cost of
occasionally mis-flagging a token in a free-text message. Fine for v1's alerting purpose; a real
grammar-based parser is a reasonable future improvement, not a correctness blocker.

## First things to verify on real hardware

In rough priority order, since each one gates the next:

1. **`swift build && swift test` from the repo root** — confirm `JTAnnunciatorCore` actually
   compiles and its tests pass. This was written without a Swift toolchain available; the code
   has had a careful manual read-through (types, field ordering against the real
   `NetworkMessage.hpp`, Optional/throws handling) but zero compiler verification.
2. **`swift run` from `Apps/Mac/JTAnnunciatorMac/`** — confirm the SwiftUI app itself builds.
   This is the layer most likely to have a real macOS-only API mistake (Network.framework
   usage, `NSOpenPanel`, SwiftUI availability).
3. **Point WSJT-X at it**: WSJT-X Settings → Reporting → enable UDP Server, host `127.0.0.1`,
   port `2237` (this app's default, changeable in its own Settings). Confirm decodes actually
   show up.
4. **Confirm the wire-format assumptions**: specifically, that `WSJTXMessageDecoder`'s field
   layout matches what your installed WSJT-X version actually sends (schema number in the
   packet header vs. what's assumed here), and that `readQDateTime`/`readQTimeMillisSinceMidnight`
   decode real timestamps correctly (there's a fixed, checkable epoch-based unit test for
   `QDateTime`, but nothing exercises it against a byte-for-byte real capture yet).
5. **DXCC lookups against a real cty.dat**: load a real file in Settings and spot-check a few
   known-tricky callsigns (a sub-entity like Conway Reef, a portable call like `G4ABC/VP8`).

## Commands

- Build/test the core package: `swift build`, `swift test` (from the repo root).
- Run the Mac app: `swift run` from `Apps/Mac/JTAnnunciatorMac/` (or open that folder — or the
  repo root — in Xcode).

## Possible next steps

Roughly in order of how directly they extend v1, not a commitment — pick up only what's
actually wanted:
- Heartbeat replies + Reply/Highlight Callsign sending, so this app is a full two-way UDP client
  instead of listen-only.
- Wanted US states/CQ-zones/continents/LoTW status, matching more of JTAlert's real category set.
- Reading existing ADIF logs on startup so "already worked" survives an app restart.
- A real FT4/FT8 standard-messages grammar parser, replacing the token-scanning heuristic.
- An Xcode project (icon, proper app bundle, entitlements, code signing) once the SPM-executable
  version above is confirmed working.
