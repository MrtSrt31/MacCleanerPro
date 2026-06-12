import Foundation

struct MaintenanceTask: Identifiable, Hashable {
    var id: String
    var title: String
    var description: String
    var systemImage: String
    var requiresAdmin: Bool
}

enum MaintenanceTaskResult {
    case success(String)
    case failure(String)
}

enum MaintenanceCatalog {
    /// Tasks safe to run without elevated privileges — available in every build.
    static let userTasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "dns-flush-user",
            title: L10n.tr("DNS Onbellegini Temizle"),
            description: L10n.tr("Tarayici ve sistem DNS onbellegini sifirlar, baglanti sorunlarini giderebilir."),
            systemImage: "network",
            requiresAdmin: false
        ),
        MaintenanceTask(
            id: "rebuild-launch-services",
            title: L10n.tr("Acilan Uygulamalar Veritabanini Yenile"),
            description: L10n.tr("Cift tiklama menulerinde tekrarlanan veya yanlis uygulama girdilerini duzeltir."),
            systemImage: "list.bullet.rectangle",
            requiresAdmin: false
        ),
        MaintenanceTask(
            id: "purge-memory",
            title: L10n.tr("Bellegi Bosalt"),
            description: L10n.tr("Inaktif bellek sayfalarini serbest birakarak sistemi rahatlatir."),
            systemImage: "memorychip",
            requiresAdmin: false
        ),
    ]

    /// Tasks that require administrator privileges — only offered in the Full build.
    static let adminTasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "dns-flush-admin",
            title: L10n.tr("Sistem DNS Onbellegini Sifirla (Admin)"),
            description: L10n.tr("mDNSResponder servisini yeniden baslatarak DNS onbellegini tamamen temizler."),
            systemImage: "network.badge.shield.half.filled",
            requiresAdmin: true
        ),
        MaintenanceTask(
            id: "rebuild-spotlight",
            title: L10n.tr("Spotlight Dizinini Yeniden Olustur"),
            description: L10n.tr("Arama sonuclari guncel degilse Spotlight veritabanini sifirdan olusturur."),
            systemImage: "magnifyingglass",
            requiresAdmin: true
        ),
        MaintenanceTask(
            id: "repair-permissions",
            title: L10n.tr("Disk Izinlerini Onar"),
            description: L10n.tr("Kullanici klasorunuzdeki dosya sahipligi ve izin sorunlarini onarir."),
            systemImage: "lock.shield",
            requiresAdmin: true
        ),
        MaintenanceTask(
            id: "clear-system-caches",
            title: L10n.tr("Sistem Onbelleklerini Temizle"),
            description: L10n.tr("/Library/Caches altindaki sistem genelindeki onbellek dosyalarini siler."),
            systemImage: "trash.slash",
            requiresAdmin: true
        ),
    ]
}

#if FULL_VERSION

enum MaintenanceRunner {
    /// Runs a non-admin maintenance task locally.
    static func run(_ task: MaintenanceTask) -> MaintenanceTaskResult {
        switch task.id {
        case "dns-flush-user":
            return runProcess("/usr/bin/dscacheutil", ["-flushcache"], successKey: "DNS onbellegi temizlendi.")
        case "rebuild-launch-services":
            let lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
            return runProcess(lsregister, ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"], successKey: "Acilan uygulamalar veritabani yenilendi.")
        case "purge-memory":
            return runProcess("/usr/sbin/purge", [], successKey: "Bellek bosaltildi.")
        default:
            return .failure(L10n.tr("Bilinmeyen gorev."))
        }
    }

    /// Runs an admin-privileged maintenance task via osascript "with administrator privileges".
    /// This relies on macOS's own AuthorizationServices prompt — no password is read or stored by this app.
    static func runWithAdmin(_ task: MaintenanceTask) -> MaintenanceTaskResult {
        let shellCommand: String
        switch task.id {
        case "dns-flush-admin":
            shellCommand = "dscacheutil -flushcache; killall -HUP mDNSResponder"
        case "rebuild-spotlight":
            shellCommand = "mdutil -E /"
        case "repair-permissions":
            shellCommand = "diskutil resetUserPermissions / `id -u`"
        case "clear-system-caches":
            shellCommand = "rm -rf /Library/Caches/*"
        default:
            return .failure(L10n.tr("Bilinmeyen gorev."))
        }

        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"

        return runProcess("/usr/bin/osascript", ["-e", appleScript], successKey: "Gorev tamamlandi.")
    }

    private static func runProcess(_ path: String, _ arguments: [String], successKey: String) -> MaintenanceTaskResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return .success(L10n.tr(successKey))
            } else {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let message, !message.isEmpty {
                    return .failure(message)
                }
                return .failure(L10n.format("Gorev basarisiz oldu (kod %d).", process.terminationStatus))
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

#endif
