import Foundation

enum DictionaryImportConflictPolicy: Sendable {
    case keepExisting
    case preferImported
}

struct DictionaryImportReport: Equatable, Sendable {
    /// Counts describe unique normalized aliases from the imported document.
    let added: Int
    let updated: Int
    let unchanged: Int
    /// Extra occurrences of an alias inside the file; the last occurrence wins.
    let duplicates: Int
    /// Distinct aliases with differing values, inside the file or against local data.
    let conflicts: Int
}
