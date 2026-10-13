/// Explicit whole-token aliases observed in the user's writing. These are not
/// general Vietnamese spelling rules and never substitute arbitrary substrings.
enum SuggestedCorrections {
    static let revision = 1
    static let pairs: [(String, String)] = [
        ("abn5", "bạn"), ("ab5n", "bạn"),
        ("haoc85", "hoặc"), ("haoc75", "hoặc"), ("cna6n", "cần"),
        ("torng", "trong"), ("modle", "model"), ("vidoe", "video"),
        ("resaerch", "research"), ("imgagen", "imagegen"),
        ("lisecne", "license"), ("swifui", "SwiftUI"), ("pricete", "private")
    ]
}
