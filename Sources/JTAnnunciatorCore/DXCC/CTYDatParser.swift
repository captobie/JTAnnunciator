import Foundation

/// Parses the "cty.dat" DXCC country-file format used by essentially every ham logging program
/// (N1MM, WSJT-X's own DXCC lookup, Log4OM, CQRLOG, ...). This app does not ship a full cty.dat
/// — accuracy matters too much to hand-author (DXCC boundaries have dozens of real, non-obvious
/// exceptions), and a maintained one is a normal download for any ham already: see the README's
/// "DXCC data" section. This parser lets the user point Settings at whichever cty.dat they
/// already trust.
///
/// Format (one entity per record, terminated by `;`):
/// ```
/// Entity Name:CQzone:ITUzone:Continent:Latitude:Longitude:UTCoffset:PrimaryPrefix:
///     alias1,alias2,...,aliasN;
/// ```
/// Alias tokens may:
/// - start with `=` to mean "this exact callsign", not a prefix,
/// - carry override suffixes attached directly (no space), any subset of: `(5)` CQ zone,
///   `[8]` ITU zone, `<12.34/-56.78>` lat/lon, `{NA}` continent — e.g. `=AH2V(5)[8]`.
///
/// Grounded against a real, current cty.dat (WSJT-X's own bundled copy) rather than assumed —
/// see this type's test fixtures, which are verbatim excerpts of that file.
enum CTYDatParser {
    private struct ParsedAlias {
        var base: String
        var isExactCallsign: Bool
        var cqZoneOverride: Int?
        var ituZoneOverride: Int?
        var continentOverride: String?
        var latLonOverride: (lat: Double, lon: Double)?
    }

    static func parse(_ text: String) -> CTYDatabase {
        var exactCallsigns: [String: CTYEntry] = [:]
        var prefixes: [String: CTYEntry] = [:]

        for rawEntry in text.components(separatedBy: ";") {
            let entryText = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entryText.isEmpty else { continue }

            let fields = entryText.components(separatedBy: ":")
            // 8 header fields (Name, CQzone, ITUzone, Continent, Lat, Lon, UTCoffset,
            // PrimaryPrefix) plus everything after the header's trailing colon = the alias list.
            guard fields.count >= 9 else { continue }
            guard
                let cqZone = Int(fields[1].trimmingCharacters(in: .whitespaces)),
                let ituZone = Int(fields[2].trimmingCharacters(in: .whitespaces)),
                let latitude = Double(fields[4].trimmingCharacters(in: .whitespaces)),
                let longitude = Double(fields[5].trimmingCharacters(in: .whitespaces)),
                let utcOffset = Double(fields[6].trimmingCharacters(in: .whitespaces))
            else { continue }

            let name = fields[0].trimmingCharacters(in: .whitespaces)
            let continent = fields[3].trimmingCharacters(in: .whitespaces)
            let primaryPrefix = fields[7]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "*")) // "*4U1V" etc.
            let aliasText = fields[8...].joined(separator: ":")

            let baseEntry = CTYEntry(
                name: name, cqZone: cqZone, ituZone: ituZone, continent: continent,
                latitude: latitude, longitude: longitude, utcOffsetHours: utcOffset,
                primaryPrefix: primaryPrefix
            )

            let aliasTokens = aliasText
                .replacingOccurrences(of: "\n", with: "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for rawToken in aliasTokens {
                let parsed = parseAliasToken(rawToken)
                guard !parsed.base.isEmpty else { continue }

                var entry = baseEntry
                if let cq = parsed.cqZoneOverride { entry.cqZone = cq }
                if let itu = parsed.ituZoneOverride { entry.ituZone = itu }
                if let continentOverride = parsed.continentOverride { entry.continent = continentOverride }
                if let latLon = parsed.latLonOverride {
                    entry.latitude = latLon.lat
                    entry.longitude = latLon.lon
                }

                let key = parsed.base.uppercased()
                if parsed.isExactCallsign {
                    exactCallsigns[key] = entry
                } else {
                    prefixes[key] = entry
                }
            }
        }

        return CTYDatabase(exactCallsigns: exactCallsigns, prefixes: prefixes)
    }

    private static func parseAliasToken(_ raw: String) -> ParsedAlias {
        var token = Substring(raw)
        let isExact = token.hasPrefix("=")
        if isExact { token = token.dropFirst() }

        var base = ""
        while let first = token.first, !"([<{".contains(first) {
            base.append(first)
            token = token.dropFirst()
        }

        var cqZoneOverride: Int?
        var ituZoneOverride: Int?
        var continentOverride: String?
        var latLonOverride: (lat: Double, lon: Double)?

        while let opener = token.first {
            let closer: Character
            switch opener {
            case "(": closer = ")"
            case "[": closer = "]"
            case "<": closer = ">"
            case "{": closer = "}"
            default:
                token = token.dropFirst()
                continue
            }
            token = token.dropFirst()
            var inner = ""
            while let next = token.first, next != closer {
                inner.append(next)
                token = token.dropFirst()
            }
            if token.first == closer { token = token.dropFirst() }

            switch opener {
            case "(": cqZoneOverride = Int(inner)
            case "[": ituZoneOverride = Int(inner)
            case "{": continentOverride = inner
            case "<":
                let parts = inner.split(separator: "/")
                if parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) {
                    latLonOverride = (lat, lon)
                }
            default:
                break
            }
        }

        return ParsedAlias(
            base: base, isExactCallsign: isExact, cqZoneOverride: cqZoneOverride,
            ituZoneOverride: ituZoneOverride, continentOverride: continentOverride,
            latLonOverride: latLonOverride
        )
    }
}
