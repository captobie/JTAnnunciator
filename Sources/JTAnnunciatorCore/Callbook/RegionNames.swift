import Foundation

/// Expands the two-letter US state and Canadian province/territory codes callbooks return
/// ("CT") into full names ("Connecticut").
public enum RegionNames {
    private static let names: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California",
        "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware", "DC": "District of Columbia",
        "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois",
        "IN": "Indiana", "IA": "Iowa", "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana",
        "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
        "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
        "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
        "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon",
        "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota",
        "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont", "VA": "Virginia",
        "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
        // Canada. "PQ" is the older code for Quebec that some callbooks still use.
        "AB": "Alberta", "BC": "British Columbia", "MB": "Manitoba", "NB": "New Brunswick",
        "NL": "Newfoundland and Labrador", "NS": "Nova Scotia", "NT": "Northwest Territories",
        "NU": "Nunavut", "ON": "Ontario", "PE": "Prince Edward Island", "QC": "Quebec",
        "PQ": "Quebec", "SK": "Saskatchewan", "YT": "Yukon",
    ]

    /// The full name for `state`, or `state` unchanged if it isn't a known US/Canadian code
    /// (or already spelled out). Codes are only expanded when the callbook's `country` is the
    /// United States or Canada, or is unknown.
    public static func fullName(forState state: String, country: String? = nil) -> String {
        let code = state.trimmingCharacters(in: .whitespaces).uppercased()
        if let country, !country.isEmpty,
           !["united states", "canada"].contains(country.lowercased()) {
            return state
        }
        return names[code] ?? state
    }
}
