import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .system: L10n.preferredSupportedLanguageCode()
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        }
    }

    var bundleLanguageCode: String {
        switch self {
        case .system: L10n.preferredSupportedLanguageCode()
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        }
    }

    var appKitLanguageCodes: [String]? {
        switch self {
        case .system: nil
        case .english: ["en"]
        case .simplifiedChinese: ["zh-Hans"]
        }
    }

    var displayName: String {
        switch self {
        case .system: L10n.tr("System Language")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

enum L10n {
    static var currentLanguage: AppLanguage = .system
    private static let fallbackLanguageCode = "en"
    private static let supportedLanguageCodes = ["en", "zh-Hans"]

    static func tr(_ key: String) -> String {
        if let path = localizedBundlePath(for: currentLanguage.bundleLanguageCode),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }

        if let path = localizedBundlePath(for: fallbackLanguageCode),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }

        return key
    }

    static func preferredSupportedLanguageCode() -> String {
        let preferred = Bundle.preferredLocalizations(from: supportedLanguageCodes).first ?? fallbackLanguageCode
        return normalizedSupportedCode(preferred) ?? fallbackLanguageCode
    }

    static func applySystemPanelLanguagePreference(_ language: AppLanguage) {
        if let languageCodes = language.appKitLanguageCodes {
            UserDefaults.standard.set(languageCodes, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    private static func localizedBundlePath(for code: String) -> String? {
        if let path = Bundle.module.path(forResource: code, ofType: "lproj") {
            return path
        }
        if let path = Bundle.module.path(forResource: code.lowercased(), ofType: "lproj") {
            return path
        }
        return Bundle.module.localizations
            .first { $0.caseInsensitiveCompare(code) == .orderedSame }
            .flatMap { Bundle.module.path(forResource: $0, ofType: "lproj") }
    }

    private static func normalizedSupportedCode(_ code: String) -> String? {
        supportedLanguageCodes.first { supported in
            supported.caseInsensitiveCompare(code) == .orderedSame
        }
    }
}
