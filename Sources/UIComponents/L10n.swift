import Foundation

public enum L10n {
    public static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }

    public static func format(_ key: String, _ args: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(key), bundle: .module)
        return String(format: format, locale: Locale.current, arguments: args)
    }
}
