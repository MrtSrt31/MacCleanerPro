import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case plan
    case automation
    case reports

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard:
            return L10n.tr("Kontrol Merkezi")
        case .plan:
            return L10n.tr("Temizlik Planı")
        case .automation:
            return L10n.tr("Otomasyon")
        case .reports:
            return L10n.tr("Raporlar")
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            return L10n.tr("Gerçek sistem klasörlerini tarar, alan kazanımını hesaplar ve seçilebilir görevler üretir.")
        case .plan:
            return L10n.tr("Seçili görevlerin etkisini, hedef boş alanı ve geri dönüş kayıtlarını birlikte gösterir.")
        case .automation:
            return L10n.tr("Bakım ritmini ve disk eşiği tercihlerini yerel ayarlar olarak saklar.")
        case .reports:
            return L10n.tr("Tarama özetini dışa aktarır ve çalışma geçmişini okunur rapor kartlarına dönüştürür.")
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "square.grid.2x2.fill"
        case .plan:
            return "checklist.checked"
        case .automation:
            return "clock.arrow.circlepath"
        case .reports:
            return "chart.bar.doc.horizontal"
        }
    }
}

enum SafetyLevel: String, CaseIterable, Codable {
    case safe = "Guvenli"
    case review = "Inceleme"
    case manual = "Manuel"

    var title: String {
        switch self {
        case .safe:
            return L10n.tr("Guvenli")
        case .review:
            return L10n.tr("Inceleme")
        case .manual:
            return L10n.tr("Manuel")
        }
    }

    var tint: Color {
        switch self {
        case .safe:
            return Color(red: 0.08, green: 0.63, blue: 0.58)
        case .review:
            return Color(red: 0.83, green: 0.49, blue: 0.28)
        case .manual:
            return Color(red: 0.49, green: 0.34, blue: 0.66)
        }
    }

    var background: Color {
        tint.opacity(0.14)
    }
}

enum CleanupActionKind: String, Codable {
    case trash
    case dockerPrune
}

enum CleanupCategory: String, CaseIterable, Identifiable, Codable {
    case userCaches
    case logArchives
    case derivedData
    case deviceSupport
    case mailDownloads
    case iosBackups
    case largeDownloads
    case docker

    var id: Self { self }

    var title: String {
        switch self {
        case .userCaches:
            return L10n.tr("Kullanici Cache")
        case .logArchives:
            return L10n.tr("Log ve Crash Arsivleri")
        case .derivedData:
            return L10n.tr("Xcode DerivedData")
        case .deviceSupport:
            return L10n.tr("Device Support ve Simulator Cache")
        case .mailDownloads:
            return L10n.tr("Mail Indirmeleri")
        case .iosBackups:
            return L10n.tr("iOS Finder Yedekleri")
        case .largeDownloads:
            return L10n.tr("Buyuk Download Dosyalari")
        case .docker:
            return L10n.tr("Docker Sistem Verisi")
        }
    }

    var subtitle: String {
        switch self {
        case .userCaches:
            return L10n.tr("Library icindeki cache klasorleri ve container cache katmanlari.")
        case .logArchives:
            return L10n.tr("Tanilama loglari, crash raporlari ve eski run kayitlari.")
        case .derivedData:
            return L10n.tr("Build artıkları, indeksler ve gecici Xcode derleme urunleri.")
        case .deviceSupport:
            return L10n.tr("Xcode cihaz destek paketleri ve CoreSimulator cache dosyalari.")
        case .mailDownloads:
            return L10n.tr("Apple Mail tarafindan lokal diske indirilen ek klasorleri.")
        case .iosBackups:
            return L10n.tr("Finder icinde biriken iPhone ve iPad yedek klasorleri.")
        case .largeDownloads:
            return L10n.tr("Downloads altinda buyuk ve eski dosyalar.")
        case .docker:
            return L10n.tr("Docker CLI varsa reclaimable alan taranir ve prune komutu calistirilabilir.")
        }
    }

    var systemImage: String {
        switch self {
        case .userCaches:
            return "shippingbox.fill"
        case .logArchives:
            return "doc.text.magnifyingglass"
        case .derivedData:
            return "hammer.fill"
        case .deviceSupport:
            return "iphone.gen3"
        case .mailDownloads:
            return "envelope.badge"
        case .iosBackups:
            return "externaldrive.badge.timemachine"
        case .largeDownloads:
            return "arrow.down.circle.fill"
        case .docker:
            return "shippingbox.circle.fill"
        }
    }

    var safety: SafetyLevel {
        switch self {
        case .userCaches, .logArchives, .derivedData, .deviceSupport:
            return .safe
        case .mailDownloads, .iosBackups, .largeDownloads:
            return .review
        case .docker:
            return .manual
        }
    }

    var defaultSelected: Bool {
        safety == .safe
    }

    var actionKind: CleanupActionKind {
        switch self {
        case .docker:
            return .dockerPrune
        default:
            return .trash
        }
    }

    var emptyStateNote: String {
        switch self {
        case .docker:
            return L10n.tr("Docker reclaimable alan bulunmadi veya Docker CLI erisilebilir degil.")
        case .largeDownloads:
            return L10n.tr("Esik kosullarini asan buyuk ve eski dosya bulunmadi.")
        default:
            return L10n.tr("Bu kategori icin temizlenebilir icerik bulunmadi.")
        }
    }
}

struct CleanupScanResult: Identifiable, Hashable, Codable {
    let category: CleanupCategory
    var bytes: Int64
    var itemCount: Int
    var itemPaths: [String]
    var notes: [String]
    var shellCommand: String?
    var scannedRoots: [String]
    var lastUpdated: Date

    var id: CleanupCategory { category }
    var safety: SafetyLevel { category.safety }
    var isEmpty: Bool { bytes == 0 || itemCount == 0 }
    var isActionable: Bool { bytes > 0 && (!itemPaths.isEmpty || shellCommand != nil) }
    var urls: [URL] { itemPaths.map(URL.init(fileURLWithPath:)) }
}

struct DiskSummary: Codable {
    var total: Int64
    var free: Int64

    var used: Int64 {
        max(0, total - free)
    }

    static let empty = DiskSummary(total: 0, free: 0)
}

struct ScanOptions: Sendable {
    var includeDeepScan: Bool
    var safeMode: Bool
    var largeDownloadThresholdMB: Int
    var largeDownloadAgeDays: Int
}

struct ScanBundle {
    var results: [CleanupScanResult]
    var diskSummary: DiskSummary
}

struct ScanStageUpdate {
    var title: String
    var detail: String
    var progress: Double
}

struct CleanupOutcome {
    var cleanedBytes: Int64
    var cleanedItems: Int
    var snapshotURL: URL?
    var warnings: [String]
}

enum MaintenanceSchedule: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: Self { self }

    var title: String {
        switch self {
        case .daily:
            return L10n.tr("Gunluk")
        case .weekly:
            return L10n.tr("Haftalik")
        case .monthly:
            return L10n.tr("Aylik")
        }
    }

    var detail: String {
        switch self {
        case .daily:
            return L10n.tr("Siklik yuksek, sistem her gun kisa taranir.")
        case .weekly:
            return L10n.tr("Dengeli bakim ritmi.")
        case .monthly:
            return L10n.tr("Daha sakin, arsiv agirlikli bakim.")
        }
    }

    var monthlyMultiplier: Double {
        switch self {
        case .daily:
            return 1.85
        case .weekly:
            return 1.10
        case .monthly:
            return 0.55
        }
    }

    func nextDate(from date: Date) -> Date {
        let calendar = Calendar.current

        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
}

enum ActivityStyle {
    case info
    case success
    case warning
    case failure

    var tint: Color {
        switch self {
        case .info:
            return Color(red: 0.30, green: 0.56, blue: 0.78)
        case .success:
            return Color(red: 0.08, green: 0.63, blue: 0.58)
        case .warning:
            return Color(red: 0.83, green: 0.49, blue: 0.28)
        case .failure:
            return Color(red: 0.76, green: 0.25, blue: 0.30)
        }
    }
}

struct ActivityEntry: Identifiable {
    let id = UUID()
    let date: Date
    let payload: LocalizedTextPayload
    let style: ActivityStyle

    var message: String {
        payload.resolved
    }
}

struct BarPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

extension Int64 {
    var formattedBytes: String {
        formatted(.byteCount(style: .file).locale(L10n.locale))
    }
}

extension Date {
    var shortTimestamp: String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var fileStamp: String {
        Self.fileFormatter.string(from: self)
    }
    private static let fileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

extension Array where Element == CleanupScanResult {
    var totalBytes: Int64 {
        reduce(0) { $0 + $1.bytes }
    }
}

enum ThemeAccent: String, CaseIterable, Identifiable, Codable {
    case tealCopper
    case blueOrange
    case greenAmber
    case purpleGold
    case indigoRose
    case slateTerra

    var id: Self { self }

    var title: String {
        switch self {
        case .tealCopper: return L10n.tr("Teal & Bakir")
        case .blueOrange: return L10n.tr("Okyanus & Mercan")
        case .greenAmber: return L10n.tr("Orman & Kehribar")
        case .purpleGold: return L10n.tr("Mor & Altin")
        case .indigoRose: return L10n.tr("Indigo & Gul")
        case .slateTerra: return L10n.tr("Arduvaz & Toprak")
        }
    }

    var primary: Color {
        switch self {
        case .tealCopper:  return Color(red: 0.08, green: 0.63, blue: 0.58)
        case .blueOrange:  return Color(red: 0.18, green: 0.48, blue: 0.86)
        case .greenAmber:  return Color(red: 0.16, green: 0.54, blue: 0.35)
        case .purpleGold:  return Color(red: 0.50, green: 0.26, blue: 0.72)
        case .indigoRose:  return Color(red: 0.28, green: 0.33, blue: 0.80)
        case .slateTerra:  return Color(red: 0.35, green: 0.44, blue: 0.52)
        }
    }

    var accent: Color {
        switch self {
        case .tealCopper:  return Color(red: 0.84, green: 0.53, blue: 0.33)
        case .blueOrange:  return Color(red: 0.96, green: 0.55, blue: 0.26)
        case .greenAmber:  return Color(red: 0.90, green: 0.66, blue: 0.18)
        case .purpleGold:  return Color(red: 0.88, green: 0.71, blue: 0.22)
        case .indigoRose:  return Color(red: 0.86, green: 0.31, blue: 0.54)
        case .slateTerra:  return Color(red: 0.76, green: 0.42, blue: 0.29)
        }
    }

    var backgroundGradient: [Color] {
        switch self {
        case .tealCopper:
            return [Color(red: 0.96, green: 0.94, blue: 0.90), Color(red: 0.95, green: 0.98, blue: 0.96), Color(red: 0.90, green: 0.96, blue: 0.94)]
        case .blueOrange:
            return [Color(red: 0.93, green: 0.95, blue: 0.99), Color(red: 0.92, green: 0.96, blue: 1.00), Color(red: 0.91, green: 0.94, blue: 0.99)]
        case .greenAmber:
            return [Color(red: 0.92, green: 0.97, blue: 0.93), Color(red: 0.93, green: 0.98, blue: 0.92), Color(red: 0.91, green: 0.97, blue: 0.92)]
        case .purpleGold:
            return [Color(red: 0.96, green: 0.93, blue: 0.99), Color(red: 0.95, green: 0.93, blue: 0.99), Color(red: 0.93, green: 0.91, blue: 0.97)]
        case .indigoRose:
            return [Color(red: 0.93, green: 0.93, blue: 0.99), Color(red: 0.95, green: 0.92, blue: 0.98), Color(red: 0.92, green: 0.91, blue: 0.97)]
        case .slateTerra:
            return [Color(red: 0.95, green: 0.94, blue: 0.93), Color(red: 0.96, green: 0.95, blue: 0.93), Color(red: 0.93, green: 0.92, blue: 0.90)]
        }
    }
}

enum SetupProfile: String, CaseIterable, Identifiable {
    case general
    case developer
    case power

    var id: Self { self }

    var title: String {
        switch self {
        case .general:    return L10n.tr("Genel Kullanim")
        case .developer:  return L10n.tr("Gelistirici")
        case .power:      return L10n.tr("Guclu Kullanici")
        }
    }

    var subtitle: String {
        switch self {
        case .general:    return L10n.tr("Temel cache ve log temizligi. Yeni baslayanlar icin ideal.")
        case .developer:  return L10n.tr("Xcode, Docker ve gelistirici araclarini kapsar.")
        case .power:      return L10n.tr("Tum kategoriler, derin tarama ve proaktif bakim.")
        }
    }

    var systemImage: String {
        switch self {
        case .general:    return "person.fill"
        case .developer:  return "hammer.fill"
        case .power:      return "bolt.fill"
        }
    }

    var safeMode: Bool    { self == .general }
    var deepScan: Bool    { self != .general }
    var schedule: MaintenanceSchedule {
        switch self {
        case .general:   return .monthly
        case .developer: return .weekly
        case .power:     return .daily
        }
    }
}