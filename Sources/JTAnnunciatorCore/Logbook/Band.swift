import Foundation

/// Amateur band lookup, spelled the way loggers do ("20M", "70CM") so it compares directly
/// against `LogbookQSO.band`.
public enum Band {
    private static let ranges: [(name: String, lowHz: UInt64, highHz: UInt64)] = [
        ("160M", 1_800_000, 2_000_000),
        ("80M", 3_500_000, 4_000_000),
        ("60M", 5_060_000, 5_450_000),
        ("40M", 7_000_000, 7_300_000),
        ("30M", 10_100_000, 10_150_000),
        ("20M", 14_000_000, 14_350_000),
        ("17M", 18_068_000, 18_168_000),
        ("15M", 21_000_000, 21_450_000),
        ("12M", 24_890_000, 24_990_000),
        ("10M", 28_000_000, 29_700_000),
        ("6M", 50_000_000, 54_000_000),
        ("2M", 144_000_000, 148_000_000),
        ("70CM", 420_000_000, 450_000_000),
    ]

    /// The band containing `frequencyHz`, or `nil` if it's outside the amateur bands listed.
    public static func name(forFrequencyHz frequencyHz: UInt64) -> String? {
        ranges.first { frequencyHz >= $0.lowHz && frequencyHz <= $0.highHz }?.name
    }
}
