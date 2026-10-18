import Foundation

public enum TonePlacement: String, CaseIterable, Codable, Identifiable {
    case traditional, modern

    public var id: String { rawValue }
    public var displayName: String {
        self == .traditional ? "Hòa, khỏe, thủy" : "Hoà, khoẻ, thuỷ"
    }
}

public struct TypingOptions: Equatable, Codable {
    public var normalizeToneOnBackspace: Bool
    public var restoreEnglishTelex: Bool
    public var tonePlacement: TonePlacement

    public init(normalizeToneOnBackspace: Bool = true, restoreEnglishTelex: Bool = false,
                tonePlacement: TonePlacement = .traditional) {
        self.normalizeToneOnBackspace = normalizeToneOnBackspace
        self.restoreEnglishTelex = restoreEnglishTelex
        self.tonePlacement = tonePlacement
    }
}
