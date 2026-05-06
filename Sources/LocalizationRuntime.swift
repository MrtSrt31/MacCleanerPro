import Combine
import Foundation

enum AppLanguageChoice: String, CaseIterable, Identifiable {
    case system
    case english
    case turkish
    case chineseSimplified
    case german
    case japanese
    case hindi
    case french
    case portuguese
    case italian
    case russian
    case spanish
    case korean
    case indonesian
    case dutch
    case arabic

    var id: Self { self }

    var resolvedLanguage: AppLanguage {
        switch self {
        case .system:
            return AppLanguage.current
        case .english:
            return .english
        case .turkish:
            return .turkish
        case .chineseSimplified:
            return .chineseSimplified
        case .german:
            return .german
        case .japanese:
            return .japanese
        case .hindi:
            return .hindi
        case .french:
            return .french
        case .portuguese:
            return .portuguese
        case .italian:
            return .italian
        case .russian:
            return .russian
        case .spanish:
            return .spanish
        case .korean:
            return .korean
        case .indonesian:
            return .indonesian
        case .dutch:
            return .dutch
        case .arabic:
            return .arabic
        }
    }

    var title: String {
        switch self {
        case .system:
            return L10n.tr("Otomatik (Sistem)")
        case .english:
            return "English"
        case .turkish:
            return "Türkçe"
        case .chineseSimplified:
            return "简体中文"
        case .german:
            return "Deutsch"
        case .japanese:
            return "日本語"
        case .hindi:
            return "हिन्दी"
        case .french:
            return "Français"
        case .portuguese:
            return "Português (Brasil)"
        case .italian:
            return "Italiano"
        case .russian:
            return "Русский"
        case .spanish:
            return "Español"
        case .korean:
            return "한국어"
        case .indonesian:
            return "Bahasa Indonesia"
        case .dutch:
            return "Nederlands"
        case .arabic:
            return "العربية"
        }
    }
}

final class LocalizationController: ObservableObject, @unchecked Sendable {
    static let shared = LocalizationController()

    @Published private(set) var selection: AppLanguageChoice

    private let defaultsKey = "MacCleanerPro.languageChoice"

    private init() {
        let storedValue = UserDefaults.standard.string(forKey: defaultsKey)
        selection = AppLanguageChoice(rawValue: storedValue ?? "") ?? .system
    }

    var effectiveLanguage: AppLanguage {
        selection.resolvedLanguage
    }

    var locale: Locale {
        effectiveLanguage.locale
    }

    func updateSelection(_ newSelection: AppLanguageChoice) {
        guard selection != newSelection else { return }
        selection = newSelection
        UserDefaults.standard.set(newSelection.rawValue, forKey: defaultsKey)
    }
}

struct LocalizedTextPayload: Hashable {
    var key: String
    var arguments: [String] = []
    var isLocalized: Bool = true

    var resolved: String {
        guard isLocalized else {
            return key
        }

        return L10n.format(key, arguments: arguments.map { $0 as CVarArg })
    }

    static func localized(_ key: String, arguments: [String] = []) -> LocalizedTextPayload {
        LocalizedTextPayload(key: key, arguments: arguments, isLocalized: true)
    }

    static func raw(_ value: String) -> LocalizedTextPayload {
        LocalizedTextPayload(key: value, arguments: [], isLocalized: false)
    }
}