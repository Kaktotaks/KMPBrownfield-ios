import Foundation

/// Lookup helpers over `Localizable.xcstrings`. Keys are identical to Android `strings.xml` (DESIGN_HANDOFF §6).
enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    /// `"due_format"` + "5 Nov 2026" -> "Due 5 Nov 2026" (positional `%1$@` formats).
    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
    }

    /// Plural-aware: `"n_tasks"`, 2 -> "2 tasks".
    static func plural(_ key: String, _ count: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString(key, comment: ""), count)
    }
}
