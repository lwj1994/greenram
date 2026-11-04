import Foundation

public enum AppLanguage: String, CaseIterable, Equatable {
    case system
    case en
    case zhHans
    case zhHant
    case ja
    case de
    case fr

    public var storageCode: String {
        rawValue
    }

    public var localeIdentifier: String {
        switch self {
        case .system:
            return Localizer.resolvedSystemLanguage().localeIdentifier
        case .en:
            return "en"
        case .zhHans:
            return "zh-Hans"
        case .zhHant:
            return "zh-Hant"
        case .ja:
            return "ja"
        case .de:
            return "de"
        case .fr:
            return "fr"
        }
    }

    public var nativeDisplayName: String {
        switch self {
        case .system:
            return "System"
        case .en:
            return "English"
        case .zhHans:
            return "简体中文"
        case .zhHant:
            return "繁體中文"
        case .ja:
            return "日本語"
        case .de:
            return "Deutsch"
        case .fr:
            return "Français"
        }
    }

    public static func from(storageCode: String?) -> AppLanguage {
        guard let storageCode, let language = AppLanguage(rawValue: storageCode) else {
            return .system
        }
        return language
    }
}

public struct Localizer: Equatable {
    public let language: AppLanguage
    private let resolvedLanguage: AppLanguage

    public init(languageCode: String? = nil) {
        self.language = AppLanguage.from(storageCode: languageCode)
        self.resolvedLanguage = language == .system ? Localizer.resolvedSystemLanguage() : language
    }

    public func t(_ key: String, _ arguments: CVarArg...) -> String {
        let template = Self.translations[key]?[resolvedLanguage] ?? Self.translations[key]?[.en] ?? key
        return String(
            format: template,
            locale: Locale(identifier: resolvedLanguage.localeIdentifier),
            arguments: arguments
        )
    }

    public static func resolvedSystemLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferredLanguages {
            let normalized = identifier.lowercased()
            if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") {
                return .zhHant
            }
            if normalized.hasPrefix("zh") {
                return .zhHans
            }
            if normalized.hasPrefix("ja") {
                return .ja
            }
            if normalized.hasPrefix("de") {
                return .de
            }
            if normalized.hasPrefix("fr") {
                return .fr
            }
            if normalized.hasPrefix("en") {
                return .en
            }
        }
        return .en
    }

    private static let translations: [String: [AppLanguage: String]] = [
        "pressure.normal": [
            .en: "Normal",
            .zhHans: "正常",
            .zhHant: "正常",
            .ja: "正常",
            .de: "Normal",
            .fr: "Normal"
        ],
        "pressure.warning": [
            .en: "Warning",
            .zhHans: "警告",
            .zhHant: "警告",
            .ja: "警告",
            .de: "Warnung",
            .fr: "Alerte"
        ],
        "pressure.critical": [
            .en: "Critical",
            .zhHans: "严重",
            .zhHant: "嚴重",
            .ja: "危険",
            .de: "Kritisch",
            .fr: "Critique"
        ],
        "menu.triggerLevel": [
            .en: "Trigger Level",
            .zhHans: "触发级别",
            .zhHant: "觸發級別",
            .ja: "トリガーレベル",
            .de: "Auslösestufe",
            .fr: "Niveau de déclenchement"
        ],
        "menu.systemPressure": [
            .en: "System Pressure",
            .zhHans: "系统压力",
            .zhHant: "系統壓力",
            .ja: "システム圧力",
            .de: "Systemdruck",
            .fr: "Pression système"
        ],
        "menu.ram": [
            .en: "RAM",
            .zhHans: "物理内存",
            .zhHant: "實體記憶體",
            .ja: "RAM",
            .de: "RAM",
            .fr: "RAM"
        ],
        "menu.swap": [
            .en: "Swap",
            .zhHans: "交换内存",
            .zhHant: "交換記憶體",
            .ja: "スワップ",
            .de: "Auslagerung",
            .fr: "Swap"
        ],
        "menu.frontmost": [
            .en: "Frontmost",
            .zhHans: "前台应用",
            .zhHant: "前台 App",
            .ja: "最前面のアプリ",
            .de: "Vordergrund",
            .fr: "Au premier plan"
        ],
        "menu.trackedApps": [
            .en: "Tracked Apps",
            .zhHans: "追踪应用数",
            .zhHant: "追蹤 App 數",
            .ja: "追跡中のアプリ",
            .de: "Überwachte Apps",
            .fr: "Apps suivies"
        ],
        "menu.thresholdStatus": [
            .en: "Threshold",
            .zhHans: "阈值",
            .zhHant: "閾值",
            .ja: "しきい値",
            .de: "Schwelle",
            .fr: "Seuil"
        ],
        "status.exceeded": [
            .en: "Exceeded",
            .zhHans: "已超过",
            .zhHant: "已超過",
            .ja: "超過",
            .de: "Überschritten",
            .fr: "Dépassé"
        ],
        "status.withinLimits": [
            .en: "Within limits",
            .zhHans: "未超过",
            .zhHant: "未超過",
            .ja: "範囲内",
            .de: "Im Limit",
            .fr: "Dans la limite"
        ],
        "menu.autoRelease": [
            .en: "Auto Clean Idle Background Apps",
            .zhHans: "自动清理超时后台 App",
            .zhHant: "自動清理逾時背景 App",
            .ja: "待機中の背景アプリを自動整理",
            .de: "Inaktive Hintergrund-Apps automatisch bereinigen",
            .fr: "Nettoyer les apps inactives en arrière-plan"
        ],
        "dashboard.candidates": [
            .en: "Cleanable",
            .zhHans: "可清理",
            .zhHant: "可清理",
            .ja: "背景",
            .de: "Hintergrund",
            .fr: "Arrière-plan"
        ],
        "dashboard.trackedApps": [
            .en: "Apps",
            .zhHans: "应用",
            .zhHant: "App",
            .ja: "アプリ",
            .de: "Apps",
            .fr: "Apps"
        ],
        "menu.aggressiveForceKill": [
            .en: "Aggressive Force Kill",
            .zhHans: "激进强杀",
            .zhHant: "激進強殺",
            .ja: "強制終了モード",
            .de: "Aggressiv beenden",
            .fr: "Forcer la fermeture"
        ],
        "menu.settings": [
            .en: "Settings...",
            .zhHans: "设置...",
            .zhHant: "設定...",
            .ja: "設定...",
            .de: "Einstellungen...",
            .fr: "Réglages..."
        ],
        "menu.checkForUpdates": [
            .en: "Check for Updates...",
            .zhHans: "检查更新...",
            .zhHant: "檢查更新...",
            .ja: "アップデートを確認...",
            .de: "Nach Updates suchen...",
            .fr: "Rechercher des mises à jour..."
        ],
        "menu.checkingForUpdates": [
            .en: "Checking for Updates...",
            .zhHans: "正在检查更新...",
            .zhHant: "正在檢查更新...",
            .ja: "アップデートを確認中...",
            .de: "Updates werden gesucht...",
            .fr: "Recherche de mises à jour..."
        ],
        "menu.installingUpdate": [
            .en: "Installing Update...",
            .zhHans: "正在安装更新...",
            .zhHant: "正在安裝更新...",
            .ja: "アップデートをインストール中...",
            .de: "Update wird installiert...",
            .fr: "Installation de la mise à jour..."
        ],
        "menu.releaseNow": [
            .en: "Clean Apps Now",
            .zhHans: "立即清理可清理 App",
            .zhHant: "立即清理可清理 App",
            .ja: "背景アプリを今すぐ整理",
            .de: "Hintergrund-Apps jetzt bereinigen",
            .fr: "Nettoyer les apps en arrière-plan"
        ],
        "menu.quit": [
            .en: "Quit",
            .zhHans: "退出",
            .zhHant: "退出",
            .ja: "終了",
            .de: "Beenden",
            .fr: "Quitter"
        ],
        "menu.protectedByDefault": [
            .en: "%@ Protected By Default",
            .zhHans: "%@ 默认保护",
            .zhHant: "%@ 預設受保護",
            .ja: "%@ は既定で保護",
            .de: "%@ ist standardmäßig geschützt",
            .fr: "%@ est protégée par défaut"
        ],
        "menu.removeAppFromWhitelist": [
            .en: "Remove %@ From Whitelist",
            .zhHans: "从白名单移除 %@",
            .zhHant: "從白名單移除 %@",
            .ja: "%@ をホワイトリストから削除",
            .de: "%@ aus der Whitelist entfernen",
            .fr: "Retirer %@ de la liste blanche"
        ],
        "menu.whitelistApp": [
            .en: "Whitelist %@",
            .zhHans: "将 %@ 加入白名单",
            .zhHant: "將 %@ 加入白名單",
            .ja: "%@ をホワイトリストへ追加",
            .de: "%@ zur Whitelist hinzufügen",
            .fr: "Ajouter %@ à la liste blanche"
        ],
        "menu.noSafeCandidates": [
            .en: "No cleanable apps",
            .zhHans: "暂无可清理 App",
            .zhHant: "暫無可清理 App",
            .ja: "対象の背景アプリはありません",
            .de: "Keine geeigneten Hintergrund-Apps",
            .fr: "Aucune app admissible en arrière-plan"
        ],
        "menu.releaseCandidates": [
            .en: "Cleanable Apps",
            .zhHans: "可清理 App",
            .zhHant: "可清理 App",
            .ja: "背景アプリ",
            .de: "Hintergrund-Apps",
            .fr: "Apps en arrière-plan"
        ],
        "menu.childProcessCount": [
            .en: "%d child processes",
            .zhHans: "%d 个子进程",
            .zhHant: "%d 個子行程",
            .ja: "子プロセス %d 個",
            .de: "%d Kindprozesse",
            .fr: "%d processus enfants"
        ],
        "menu.childProcessCleanable": [
            .en: "%d idle, will be cleaned",
            .zhHans: "%d 个闲置待清理",
            .zhHant: "%d 個閒置待清理",
            .ja: "アイドル %d 個・終了予定",
            .de: "%d inaktiv, wird beendet",
            .fr: "%d inactifs, seront arrêtés"
        ],
        "menu.childProcessOthers": [
            .en: "%d more processes · %@",
            .zhHans: "其他 %d 个进程 · %@",
            .zhHant: "其他 %d 個行程 · %@",
            .ja: "ほか %d 個のプロセス · %@",
            .de: "%d weitere Prozesse · %@",
            .fr: "%d autres processus · %@"
        ],
        "menu.cleanable": [
            .en: "Cleanable",
            .zhHans: "可清理",
            .zhHant: "可清理",
            .ja: "清理可",
            .de: "Bereinigbar",
            .fr: "Nettoyable"
        ],
        "menu.protected": [
            .en: "Protected",
            .zhHans: "受保护",
            .zhHant: "受保護",
            .ja: "保護中",
            .de: "Geschützt",
            .fr: "Protégée"
        ],
        "menu.notCleanable": [
            .en: "Not Cleanable",
            .zhHans: "不可清理",
            .zhHant: "不可清理",
            .ja: "清理しない",
            .de: "Wird nicht bereinigt",
            .fr: "Non nettoyée"
        ],
        "menu.noBackgroundApps": [
            .en: "No apps",
            .zhHans: "没有 App",
            .zhHant: "沒有 App",
            .ja: "アプリなし",
            .de: "Keine Apps",
            .fr: "Aucune app"
        ],
        "menu.backgroundApps": [
            .en: "All Apps",
            .zhHans: "全部 App",
            .zhHant: "全部 App",
            .ja: "すべてのアプリ",
            .de: "Alle Apps",
            .fr: "Toutes les apps"
        ],
        "menu.noWhitelistItems": [
            .en: "No whitelist items",
            .zhHans: "没有白名单项",
            .zhHant: "沒有白名單項目",
            .ja: "ホワイトリスト項目なし",
            .de: "Keine Whitelist-Einträge",
            .fr: "Aucune entrée dans la liste blanche"
        ],
        "menu.removeBundleID": [
            .en: "Remove %@",
            .zhHans: "移除 %@",
            .zhHant: "移除 %@",
            .ja: "%@ を削除",
            .de: "%@ entfernen",
            .fr: "Retirer %@"
        ],
        "menu.defaultProtected": [
            .en: "Default protected: %d",
            .zhHans: "默认保护：%d",
            .zhHant: "預設保護：%d",
            .ja: "既定の保護：%d",
            .de: "Standardmäßig geschützt: %d",
            .fr: "Protégées par défaut : %d"
        ],
        "menu.whitelist": [
            .en: "Whitelist",
            .zhHans: "白名单",
            .zhHant: "白名單",
            .ja: "ホワイトリスト",
            .de: "Whitelist",
            .fr: "Liste blanche"
        ],
        "menu.noEvents": [
            .en: "No events yet",
            .zhHans: "暂无事件",
            .zhHant: "尚無事件",
            .ja: "イベントはまだありません",
            .de: "Noch keine Ereignisse",
            .fr: "Aucun événement"
        ],
        "menu.recentEvents": [
            .en: "Recent Events",
            .zhHans: "最近事件",
            .zhHant: "最近事件",
            .ja: "最近のイベント",
            .de: "Letzte Ereignisse",
            .fr: "Événements récents"
        ],
        "settings.title": [
            .en: "GreenRAM Settings",
            .zhHans: "GreenRAM 设置",
            .zhHant: "GreenRAM 設定",
            .ja: "GreenRAM 設定",
            .de: "GreenRAM Einstellungen",
            .fr: "Réglages GreenRAM"
        ],
        "update.availableTitle": [
            .en: "GreenRAM %@ is available",
            .zhHans: "GreenRAM %@ 可用",
            .zhHant: "GreenRAM %@ 可用",
            .ja: "GreenRAM %@ を利用できます",
            .de: "GreenRAM %@ ist verfügbar",
            .fr: "GreenRAM %@ est disponible"
        ],
        "update.availableMessage": [
            .en: "You are using %@. Download the latest release from GitHub.",
            .zhHans: "当前版本是 %@。可以从 GitHub 下载最新版本。",
            .zhHant: "目前版本是 %@。可以從 GitHub 下載最新版本。",
            .ja: "現在のバージョンは %@ です。GitHub から最新版をダウンロードできます。",
            .de: "Aktuelle Version: %@. Die neueste Version kann von GitHub geladen werden.",
            .fr: "Version actuelle : %@. La dernière version peut être téléchargée depuis GitHub."
        ],
        "update.download": [
            .en: "Download",
            .zhHans: "下载",
            .zhHant: "下載",
            .ja: "ダウンロード",
            .de: "Laden",
            .fr: "Télécharger"
        ],
        "update.installAndRestart": [
            .en: "Install and Restart",
            .zhHans: "安装并重启",
            .zhHant: "安裝並重啟",
            .ja: "インストールして再起動",
            .de: "Installieren und neu starten",
            .fr: "Installer et redémarrer"
        ],
        "update.releasePage": [
            .en: "Release Page",
            .zhHans: "发布页",
            .zhHant: "發布頁",
            .ja: "リリースページ",
            .de: "Release-Seite",
            .fr: "Page de version"
        ],
        "update.later": [
            .en: "Later",
            .zhHans: "稍后",
            .zhHant: "稍後",
            .ja: "あとで",
            .de: "Später",
            .fr: "Plus tard"
        ],
        "update.upToDateTitle": [
            .en: "GreenRAM is up to date",
            .zhHans: "GreenRAM 已是最新版本",
            .zhHant: "GreenRAM 已是最新版本",
            .ja: "GreenRAM は最新です",
            .de: "GreenRAM ist aktuell",
            .fr: "GreenRAM est à jour"
        ],
        "update.upToDateMessage": [
            .en: "Current version: %@.",
            .zhHans: "当前版本：%@。",
            .zhHant: "目前版本：%@。",
            .ja: "現在のバージョン：%@。",
            .de: "Aktuelle Version: %@.",
            .fr: "Version actuelle : %@."
        ],
        "update.checkFailedTitle": [
            .en: "Update check failed",
            .zhHans: "检查更新失败",
            .zhHant: "檢查更新失敗",
            .ja: "アップデート確認に失敗しました",
            .de: "Update-Prüfung fehlgeschlagen",
            .fr: "Échec de la recherche de mise à jour"
        ],
        "update.checkFailedMessage": [
            .en: "%@",
            .zhHans: "%@",
            .zhHant: "%@",
            .ja: "%@",
            .de: "%@",
            .fr: "%@"
        ],
        "update.installFailedTitle": [
            .en: "Update install failed",
            .zhHans: "安装更新失败",
            .zhHant: "安裝更新失敗",
            .ja: "アップデートのインストールに失敗しました",
            .de: "Update-Installation fehlgeschlagen",
            .fr: "Échec de l'installation de la mise à jour"
        ],
        "update.installFailedMessage": [
            .en: "%@",
            .zhHans: "%@",
            .zhHant: "%@",
            .ja: "%@",
            .de: "%@",
            .fr: "%@"
        ],
        "update.ok": [
            .en: "OK",
            .zhHans: "好",
            .zhHant: "好",
            .ja: "OK",
            .de: "OK",
            .fr: "OK"
        ],
        "settings.updates": [
            .en: "Updates",
            .zhHans: "更新",
            .zhHant: "更新",
            .ja: "アップデート",
            .de: "Updates",
            .fr: "Mises à jour"
        ],
        "settings.about": [
            .en: "About",
            .zhHans: "关于",
            .zhHant: "關於",
            .ja: "情報",
            .de: "Info",
            .fr: "À propos"
        ],
        "settings.version": [
            .en: "Version",
            .zhHans: "版本",
            .zhHant: "版本",
            .ja: "バージョン",
            .de: "Version",
            .fr: "Version"
        ],
        "settings.automaticUpdateReminder": [
            .en: "Automatic update reminders",
            .zhHans: "自动更新提醒",
            .zhHant: "自動更新提醒",
            .ja: "アップデート通知",
            .de: "Automatische Update-Hinweise",
            .fr: "Rappels automatiques de mise à jour"
        ],
        "settings.automaticUpdateReminderHint": [
            .en: "GreenRAM checks GitHub in the background at most once per day and prompts when a new version is available.",
            .zhHans: "GreenRAM 每天最多在后台检查一次 GitHub；有新版本时会提醒安装。",
            .zhHant: "GreenRAM 每天最多在背景檢查一次 GitHub；有新版本時會提醒安裝。",
            .ja: "GreenRAM はバックグラウンドで GitHub を 1 日 1 回まで確認し、新しいバージョンがあると通知します。",
            .de: "GreenRAM prüft GitHub im Hintergrund höchstens einmal pro Tag und zeigt bei einer neuen Version einen Hinweis.",
            .fr: "GreenRAM vérifie GitHub en arrière-plan au plus une fois par jour et vous prévient lorsqu'une nouvelle version est disponible."
        ],
        "settings.language": [
            .en: "Language",
            .zhHans: "语言",
            .zhHant: "語言",
            .ja: "言語",
            .de: "Sprache",
            .fr: "Langue"
        ],
        "settings.currentMemory": [
            .en: "Current Memory",
            .zhHans: "当前内存",
            .zhHant: "目前記憶體",
            .ja: "現在のメモリ",
            .de: "Aktueller Speicher",
            .fr: "Mémoire actuelle"
        ],
        "settings.ramUsed": [
            .en: "RAM Used",
            .zhHans: "物理内存",
            .zhHant: "實體記憶體",
            .ja: "使用中のRAM",
            .de: "Verwendeter RAM",
            .fr: "RAM utilisée"
        ],
        "settings.swapUsed": [
            .en: "Swap Used",
            .zhHans: "交换内存",
            .zhHant: "交換記憶體",
            .ja: "使用中のスワップ",
            .de: "Verwendete Auslagerung",
            .fr: "Swap utilisé"
        ],
        "settings.releaseThresholds": [
            .en: "Status Limits",
            .zhHans: "清理触发限制",
            .zhHant: "清理觸發限制",
            .ja: "状態表示の上限",
            .de: "Status-Grenzwerte",
            .fr: "Limites d'etat"
        ],
        "settings.autoReleaseCheckbox": [
            .en: "Auto clean idle background apps",
            .zhHans: "自动清理超时后台 App",
            .zhHant: "自動清理逾時背景 App",
            .ja: "待機中の背景アプリを自動整理",
            .de: "Inaktive Hintergrund-Apps automatisch bereinigen",
            .fr: "Nettoyer les apps inactives en arrière-plan"
        ],
        "settings.ramLimit": [
            .en: "RAM Max",
            .zhHans: "RAM 最大值",
            .zhHant: "RAM 最大值",
            .ja: "RAM上限",
            .de: "RAM-Maximum",
            .fr: "RAM max"
        ],
        "settings.swapLimit": [
            .en: "Swap Max",
            .zhHans: "交换内存限制",
            .zhHant: "交換記憶體限制",
            .ja: "Swap上限",
            .de: "Swap-Maximum",
            .fr: "Swap max"
        ],
        "settings.swapLimitEnabled": [
            .en: "Use Swap limit",
            .zhHans: "启用交换内存限制",
            .zhHant: "啟用交換記憶體限制",
            .ja: "Swap上限を使う",
            .de: "Swap-Limit verwenden",
            .fr: "Utiliser la limite Swap"
        ],
        "settings.swapMinimumHint": [
            .en: "Swap uses disk as virtual memory. Sustained high swap can slow apps down. General recommendation: 8 GB or less.",
            .zhHans: "交换内存会占用磁盘作为虚拟内存。数值持续偏高时，App 可能变慢；一般建议设置为 8GB 以内。",
            .zhHant: "交換記憶體會占用磁碟作為虛擬記憶體。數值持續偏高時，App 可能變慢；一般建議設定為 8GB 以內。",
            .ja: "既定値は物理メモリの半分、最小は2GBです。無視するにはオフにします。",
            .de: "Standard ist die Hälfte des physischen RAMs, mindestens 2 GB. Zum Ignorieren ausschalten.",
            .fr: "Par défaut: moitié de la RAM physique, minimum 2 Go. Désactivez pour ignorer le swap."
        ],
        "settings.ramWarning": [
            .en: "RAM warning",
            .zhHans: "物理内存警告",
            .zhHant: "實體記憶體警告",
            .ja: "RAM警告",
            .de: "RAM-Warnung",
            .fr: "Alerte RAM"
        ],
        "settings.ramCritical": [
            .en: "RAM critical",
            .zhHans: "物理内存严重",
            .zhHant: "實體記憶體嚴重",
            .ja: "RAM危険",
            .de: "RAM kritisch",
            .fr: "RAM critique"
        ],
        "settings.swapWarning": [
            .en: "Swap warning",
            .zhHans: "交换内存警告",
            .zhHant: "交換記憶體警告",
            .ja: "スワップ警告",
            .de: "Auslagerung Warnung",
            .fr: "Alerte swap"
        ],
        "settings.swapCritical": [
            .en: "Swap critical",
            .zhHans: "交换内存严重",
            .zhHant: "交換記憶體嚴重",
            .ja: "スワップ危険",
            .de: "Auslagerung kritisch",
            .fr: "Swap critique"
        ],
        "settings.minimumBackgroundTime": [
            .en: "Background time",
            .zhHans: "非前台时间",
            .zhHant: "非前台時間",
            .ja: "背景時間",
            .de: "Hintergrundzeit",
            .fr: "Temps en arrière-plan"
        ],
        "settings.defaultBackgroundTime": [
            .en: "Default background time",
            .zhHans: "默认非前台时间",
            .zhHant: "預設非前台時間",
            .ja: "既定の背景時間",
            .de: "Standard-Hintergrundzeit",
            .fr: "Temps arriere-plan par defaut"
        ],
        "settings.rules": [
            .en: "App Rules",
            .zhHans: "应用规则",
            .zhHant: "App 規則",
            .ja: "アプリルール",
            .de: "App-Regeln",
            .fr: "Règles des apps"
        ],
        "settings.manageRules": [
            .en: "Manage app rules",
            .zhHans: "管理应用规则",
            .zhHant: "管理 App 規則",
            .ja: "アプリルールを管理",
            .de: "App-Regeln verwalten",
            .fr: "Gérer les règles des apps"
        ],
        "settings.rulesSummary": [
            .en: "%d auto-quit apps · %d timeouts · %d memory limits · %d protected apps",
            .zhHans: "%d 个超时自动关闭 App · %d 个超时时间 · %d 个内存上限 · %d 个保护项",
            .zhHant: "%d 個逾時自動關閉 App · %d 個逾時時間 · %d 個記憶體上限 · %d 個保護項",
            .ja: "自動終了アプリ %d 件 · タイムアウト %d 件 · メモリ上限 %d 件 · 保護中 %d 件",
            .de: "%d Auto-Beenden-Apps · %d Zeiten · %d Speicherlimits · %d geschützte Apps",
            .fr: "%d apps en auto-fermeture · %d delais · %d limites mémoire · %d apps protégées"
        ],
        "settings.rulesPageHint": [
            .en: "Choose a rule type, then manage its apps on the next page.",
            .zhHans: "先选择规则类型，再到下一页管理参与的 App。",
            .zhHant: "先選擇規則類型，再到下一頁管理參與的 App。",
            .ja: "ルールの種類を選び、次のページで対象アプリを管理します。",
            .de: "Wähle einen Regeltyp und verwalte die Apps auf der nächsten Seite.",
            .fr: "Choisissez un type de règle, puis gérez ses apps sur la page suivante."
        ],
        "settings.autoQuitApps": [
            .en: "Auto-Quit Apps",
            .zhHans: "超时自动关闭",
            .zhHant: "逾時自動關閉",
            .ja: "自動終了するアプリ",
            .de: "Apps automatisch beenden",
            .fr: "Apps en auto-fermeture"
        ],
        "settings.autoQuitAppsHint": [
            .en: "Apps added here quit when their background-time threshold is reached, without waiting for RAM or Swap limits.",
            .zhHans: "加入这里的 App，达到非前台时间阈值就退出，不等待 RAM 或 Swap 超限。",
            .zhHant: "加入這裡的 App，達到非前台時間閾值就退出，不等待 RAM 或 Swap 超限。",
            .ja: "ここに追加したアプリは、背景時間のしきい値に達すると、RAMやSwapの上限を待たずに終了します。",
            .de: "Apps in dieser Liste werden beendet, sobald ihre Hintergrundzeit erreicht ist, ohne auf RAM- oder Swap-Grenzen zu warten.",
            .fr: "Les apps ajoutees ici se ferment au seuil d'arriere-plan, sans attendre les limites RAM ou Swap."
        ],
        "settings.autoQuitAppsSummary": [
            .en: "%d apps quit by time only",
            .zhHans: "%d 个 App 只按时间退出",
            .zhHant: "%d 個 App 只按時間退出",
            .ja: "%d 件のアプリは時間だけで終了",
            .de: "%d Apps werden nur nach Zeit beendet",
            .fr: "%d apps se ferment au temps seul"
        ],
        "settings.noAutoQuitItems": [
            .en: "No auto-quit apps",
            .zhHans: "没有超时自动关闭的 App",
            .zhHant: "沒有逾時自動關閉的 App",
            .ja: "自動終了アプリはありません",
            .de: "Keine Apps zum automatischen Beenden",
            .fr: "Aucune app en auto-fermeture"
        ],
        "settings.removeAutoQuitApp": [
            .en: "Remove %@ from Auto-Quit Apps",
            .zhHans: "从超时自动关闭中移除 %@",
            .zhHant: "從逾時自動關閉中移除 %@",
            .ja: "%@ を自動終了アプリから削除",
            .de: "%@ aus Auto-Beenden-Apps entfernen",
            .fr: "Retirer %@ des apps en auto-fermeture"
        ],
        "settings.appIdleTimes": [
            .en: "App Timeouts",
            .zhHans: "单 App 超时时间",
            .zhHant: "單 App 逾時時間",
            .ja: "アプリ別タイムアウト",
            .de: "App-Zeitlimits",
            .fr: "Délais par app"
        ],
        "settings.appIdleTimesHint": [
            .en: "Set per-app non-frontmost timeouts. Apps without a custom value use the global default.",
            .zhHans: "给每个 App 单独设置非前台超时时间。没设置的 App 使用全局默认值。",
            .zhHant: "給每個 App 單獨設定非前台逾時時間。沒設定的 App 使用全域預設值。",
            .ja: "アプリ別の非前面タイムアウトを設定します。未設定のアプリは全体の既定値を使います。",
            .de: "Lege App-spezifische Hintergrund-Zeitlimits fest. Ohne eigenen Wert gilt die globale Vorgabe.",
            .fr: "Définit des délais hors premier plan par app. Sans valeur dédiée, le défaut global s'applique."
        ],
        "settings.appIdleTimesSummary": [
            .en: "%d apps override the global timeout",
            .zhHans: "%d 个 App 覆盖全局超时时间",
            .zhHant: "%d 個 App 覆蓋全域逾時時間",
            .ja: "%d 件のアプリが全体の時間を上書き",
            .de: "%d Apps überschreiben die globale Zeit",
            .fr: "%d apps remplacent le délai global"
        ],
        "settings.noAppIdleTimeItems": [
            .en: "No app timeouts",
            .zhHans: "没有单 App 超时时间",
            .zhHant: "沒有單 App 逾時時間",
            .ja: "個別時間はありません",
            .de: "Keine App-Zeitlimits",
            .fr: "Aucun délai par app"
        ],
        "settings.removeAppIdleTime": [
            .en: "Remove timeout for %@",
            .zhHans: "移除 %@ 的超时时间",
            .zhHant: "移除 %@ 的逾時時間",
            .ja: "%@ の個別時間を削除",
            .de: "Zeitlimit fuer %@ entfernen",
            .fr: "Supprimer le délai pour %@"
        ],
        "settings.appMemoryLimits": [
            .en: "App Memory Limits",
            .zhHans: "单 App 内存上限",
            .zhHant: "單 App 記憶體上限",
            .ja: "アプリ別メモリ上限",
            .de: "App-Speicherlimits",
            .fr: "Limites mémoire par app"
        ],
        "settings.appMemoryLimitsHint": [
            .en: "Apps added here can be quit when their own memory use reaches the limit and their non-frontmost timeout has passed.",
            .zhHans: "加入这里的 App，自己的内存达到上限且非前台超时后，就可以被清理。",
            .zhHant: "加入這裡的 App，自己的記憶體達到上限且非前台逾時後，就可以被清理。",
            .ja: "ここに追加したアプリは、メモリ使用量が上限に達し、非前面タイムアウトを過ぎると終了対象になります。",
            .de: "Apps in dieser Liste können beendet werden, wenn ihr Speicherlimit erreicht ist und die Hintergrundzeit abgelaufen ist.",
            .fr: "Les apps ajoutees ici peuvent se fermer quand leur mémoire atteint la limite et que leur délai hors premier plan est passé."
        ],
        "settings.appMemoryLimitsSummary": [
            .en: "%d apps have their own memory limit",
            .zhHans: "%d 个 App 有独立内存上限",
            .zhHant: "%d 個 App 有獨立記憶體上限",
            .ja: "%d 件のアプリに個別メモリ上限",
            .de: "%d Apps haben ein eigenes Speicherlimit",
            .fr: "%d apps ont leur propre limite mémoire"
        ],
        "settings.noAppMemoryLimitItems": [
            .en: "No app memory limits",
            .zhHans: "没有单 App 内存上限",
            .zhHant: "沒有單 App 記憶體上限",
            .ja: "アプリ別メモリ上限はありません",
            .de: "Keine App-Speicherlimits",
            .fr: "Aucune limite mémoire par app"
        ],
        "settings.removeAppMemoryLimit": [
            .en: "Remove memory limit for %@",
            .zhHans: "移除 %@ 的内存上限",
            .zhHant: "移除 %@ 的記憶體上限",
            .ja: "%@ のメモリ上限を削除",
            .de: "Speicherlimit fuer %@ entfernen",
            .fr: "Supprimer la limite mémoire pour %@"
        ],
        "settings.whitelistSummary": [
            .en: "%d apps are protected",
            .zhHans: "%d 个 App 受保护",
            .zhHant: "%d 個 App 受保護",
            .ja: "%d 件のアプリを保護",
            .de: "%d Apps sind geschützt",
            .fr: "%d apps sont protégées"
        ],
        "settings.ruleBlockedByWhitelistTitle": [
            .en: "App is protected",
            .zhHans: "App 已在白名单",
            .zhHant: "App 已在白名單",
            .ja: "アプリは保護されています",
            .de: "App ist geschützt",
            .fr: "App protégée"
        ],
        "settings.ruleBlockedByWhitelistMessage": [
            .en: "%@ is already in the whitelist. Remove it from Protected Apps before adding other rules.",
            .zhHans: "%@ 已经在白名单里。先从保护 App 中移除它，才能添加其他规则。",
            .zhHant: "%@ 已經在白名單裡。先從保護 App 中移除它，才能加入其他規則。",
            .ja: "%@ はすでにホワイトリストにあります。他のルールを追加する前に保護対象から削除してください。",
            .de: "%@ ist bereits in der Whitelist. Entferne die App zuerst aus den geschützten Apps, bevor du andere Regeln hinzufügst.",
            .fr: "%@ est déjà dans la liste blanche. Retirez-la des apps protégées avant d'ajouter d'autres règles."
        ],
        "settings.warningIdleTime": [
            .en: "Warning background time",
            .zhHans: "警告非前台时间",
            .zhHant: "警告非前台時間",
            .ja: "警告時の背景時間",
            .de: "Hintergrundzeit bei Warnung",
            .fr: "Temps en arrière-plan en alerte"
        ],
        "settings.criticalIdleTime": [
            .en: "Critical background time",
            .zhHans: "严重非前台时间",
            .zhHant: "嚴重非前台時間",
            .ja: "危険時の背景時間",
            .de: "Hintergrundzeit kritisch",
            .fr: "Temps en arrière-plan critique"
        ],
        "settings.maxAppsPerSweep": [
            .en: "Max apps per sweep",
            .zhHans: "每轮最多处理",
            .zhHant: "每輪最多處理",
            .ja: "1回の最大アプリ数",
            .de: "Max. Apps pro Lauf",
            .fr: "Apps max par passage"
        ],
        "settings.resetDefaults": [
            .en: "Reset Defaults",
            .zhHans: "恢复默认",
            .zhHant: "恢復預設",
            .ja: "既定値に戻す",
            .de: "Standardwerte",
            .fr: "Valeurs par défaut"
        ],
        "settings.resetConfirmTitle": [
            .en: "Reset cleanup settings?",
            .zhHans: "恢复清理设置默认值？",
            .zhHant: "恢復清理設定預設值？",
            .ja: "整理設定を既定値に戻しますか？",
            .de: "Bereinigungseinstellungen zuruecksetzen?",
            .fr: "Reinitialiser les reglages de nettoyage ?"
        ],
        "settings.resetConfirmMessage": [
            .en: "This restores cleanup limits and removes Auto-Quit Apps, app timeouts, and app memory limits. Language will stay unchanged.",
            .zhHans: "这会恢复清理限制，并移除超时自动关闭、单 App 超时时间和单 App 内存上限。语言设置不会改变。",
            .zhHant: "這會恢復清理限制，並移除逾時自動關閉、單 App 逾時時間和單 App 記憶體上限。語言設定不會改變。",
            .ja: "整理の上限を既定値に戻し、自動終了アプリ、アプリ別時間、アプリ別メモリ上限を削除します。言語設定は変更されません。",
            .de: "Das setzt Bereinigungsgrenzen zurück und entfernt Auto-Beenden-Apps, App-Zeitlimits und App-Speicherlimits. Die Sprache bleibt unverändert.",
            .fr: "Les limites de nettoyage seront retablies, et les apps en auto-fermeture, délais par app et limites mémoire seront supprimés. La langue restera inchangée."
        ],
        "settings.resetConfirmButton": [
            .en: "Reset",
            .zhHans: "恢复默认",
            .zhHant: "恢復預設",
            .ja: "戻す",
            .de: "Zurücksetzen",
            .fr: "Réinitialiser"
        ],
        "settings.cancel": [
            .en: "Cancel",
            .zhHans: "取消",
            .zhHant: "取消",
            .ja: "キャンセル",
            .de: "Abbrechen",
            .fr: "Annuler"
        ],
        "settings.addBundleID": [
            .en: "Add",
            .zhHans: "添加",
            .zhHant: "新增",
            .ja: "追加",
            .de: "Hinzufügen",
            .fr: "Ajouter"
        ],
        "settings.chooseApp": [
            .en: "Choose App...",
            .zhHans: "选择 App...",
            .zhHant: "選擇 App...",
            .ja: "Appを選択...",
            .de: "App auswählen...",
            .fr: "Choisir une app..."
        ],
        "settings.bundleIDPlaceholder": [
            .en: "Bundle ID",
            .zhHans: "Bundle ID",
            .zhHant: "Bundle ID",
            .ja: "Bundle ID",
            .de: "Bundle ID",
            .fr: "Bundle ID"
        ],
        "settings.defaultWhitelistSeed": [
            .en: "Default item",
            .zhHans: "默认项",
            .zhHant: "預設項",
            .ja: "既定項目",
            .de: "Standardeintrag",
            .fr: "Entrée par défaut"
        ],
        "settings.logs": [
            .en: "Logs",
            .zhHans: "日志",
            .zhHant: "日誌",
            .ja: "ログ",
            .de: "Protokolle",
            .fr: "Journaux"
        ],
        "settings.exportLogs": [
            .en: "Export Logs",
            .zhHans: "导出日志",
            .zhHant: "匯出日誌",
            .ja: "ログを書き出す",
            .de: "Protokolle exportieren",
            .fr: "Exporter les journaux"
        ],
        "settings.exportLogsFailed": [
            .en: "Export failed",
            .zhHans: "导出失败",
            .zhHant: "匯出失敗",
            .ja: "書き出しに失敗しました",
            .de: "Export fehlgeschlagen",
            .fr: "Échec de l’export"
        ],
        "settings.logRetentionHint": [
            .en: "GreenRAM keeps events from the last 3 days. Export includes automatic cleanups, manual actions, settings changes, and whitelist changes.",
            .zhHans: "GreenRAM 会保留最近 3 天事件。导出内容包含自动清理、手动操作、设置变更和白名单变更。",
            .zhHant: "GreenRAM 會保留最近 3 天事件。匯出內容包含自動清理、手動操作、設定變更和白名單變更。",
            .ja: "GreenRAMは直近3日間のイベントを保持します。自動整理、手動操作、設定変更、ホワイトリスト変更を含みます。",
            .de: "GreenRAM speichert Ereignisse der letzten 3 Tage. Der Export enthält automatische Bereinigungen, manuelle Aktionen, Einstellungen und Whitelist-Änderungen.",
            .fr: "GreenRAM conserve les événements des 3 derniers jours. L’export inclut nettoyages automatiques, actions manuelles, réglages et liste blanche."
        ],
        "unit.hours": [
            .en: "hours",
            .zhHans: "小时",
            .zhHant: "小時",
            .ja: "時間",
            .de: "Stunden",
            .fr: "heures"
        ],
        "unit.minutes": [
            .en: "minutes",
            .zhHans: "分钟",
            .zhHant: "分鐘",
            .ja: "分",
            .de: "Minuten",
            .fr: "minutes"
        ],
        "unit.apps": [
            .en: "apps",
            .zhHans: "个应用",
            .zhHant: "個 App",
            .ja: "個のアプリ",
            .de: "Apps",
            .fr: "apps"
        ],
        "duration.secondsBg": [
            .en: "%ds bg",
            .zhHans: "后台 %d 秒",
            .zhHant: "背景 %d 秒",
            .ja: "背景 %d秒",
            .de: "%d s im Hintergrund",
            .fr: "%d s arrière-plan"
        ],
        "duration.minutesBg": [
            .en: "%dm bg",
            .zhHans: "后台 %d 分钟",
            .zhHant: "背景 %d 分鐘",
            .ja: "背景 %d分",
            .de: "%d min im Hintergrund",
            .fr: "%d min arrière-plan"
        ],
        "duration.hoursBg": [
            .en: "%.1fh bg",
            .zhHans: "后台 %.1f 小时",
            .zhHant: "背景 %.1f 小時",
            .ja: "背景 %.1f時間",
            .de: "%.1f h im Hintergrund",
            .fr: "%.1f h arrière-plan"
        ],
        "duration.idleMinutes": [
            .en: "idle %d min",
            .zhHans: "闲置 %d 分钟",
            .zhHant: "閒置 %d 分鐘",
            .ja: "アイドル %d分",
            .de: "%d min inaktiv",
            .fr: "inactif %d min"
        ],
        "duration.idleHours": [
            .en: "idle %.1f h",
            .zhHans: "闲置 %.1f 小时",
            .zhHant: "閒置 %.1f 小時",
            .ja: "アイドル %.1f時間",
            .de: "%.1f h inaktiv",
            .fr: "inactif %.1f h"
        ],
        "event.started": [
            .en: "GreenRAM started.",
            .zhHans: "GreenRAM 已启动。",
            .zhHant: "GreenRAM 已啟動。",
            .ja: "GreenRAM を起動しました。",
            .de: "GreenRAM wurde gestartet.",
            .fr: "GreenRAM a démarré."
        ],
        "event.updateAvailable": [
            .en: "Update available: %@ (current %@).",
            .zhHans: "发现新版本：%@（当前 %@）。",
            .zhHant: "發現新版本：%@（目前 %@）。",
            .ja: "アップデートがあります：%@（現在 %@）。",
            .de: "Update verfügbar: %@ (aktuell %@).",
            .fr: "Mise à jour disponible : %@ (actuelle %@)."
        ],
        "event.updateNotAvailable": [
            .en: "No update available. Current version: %@.",
            .zhHans: "没有可用更新。当前版本：%@。",
            .zhHant: "沒有可用更新。目前版本：%@。",
            .ja: "利用可能なアップデートはありません。現在のバージョン：%@。",
            .de: "Kein Update verfügbar. Aktuelle Version: %@.",
            .fr: "Aucune mise à jour disponible. Version actuelle : %@."
        ],
        "event.updateCheckFailed": [
            .en: "Update check failed: %@.",
            .zhHans: "检查更新失败：%@。",
            .zhHant: "檢查更新失敗：%@。",
            .ja: "アップデート確認に失敗しました：%@。",
            .de: "Update-Prüfung fehlgeschlagen: %@.",
            .fr: "Échec de la recherche de mise à jour : %@."
        ],
        "event.updateInstallStarted": [
            .en: "Installing update %@.",
            .zhHans: "正在安装更新 %@。",
            .zhHant: "正在安裝更新 %@。",
            .ja: "アップデート %@ をインストール中。",
            .de: "Update %@ wird installiert.",
            .fr: "Installation de la mise à jour %@."
        ],
        "event.updateInstallRelaunching": [
            .en: "Relaunching into update %@.",
            .zhHans: "正在重启到更新 %@。",
            .zhHant: "正在重啟到更新 %@。",
            .ja: "アップデート %@ で再起動中。",
            .de: "Neustart mit Update %@.",
            .fr: "Redémarrage vers la mise à jour %@."
        ],
        "event.updateInstallFailed": [
            .en: "Update install failed: %@.",
            .zhHans: "安装更新失败：%@。",
            .zhHant: "安裝更新失敗：%@。",
            .ja: "アップデートのインストールに失敗しました：%@。",
            .de: "Update-Installation fehlgeschlagen: %@.",
            .fr: "Échec de l'installation de la mise à jour : %@."
        ],
        "event.memoryPressureChanged": [
            .en: "Memory pressure changed to %@.",
            .zhHans: "内存压力变为 %@。",
            .zhHant: "記憶體壓力變為 %@。",
            .ja: "メモリ圧力が %@ になりました。",
            .de: "Speicherdruck geändert zu %@.",
            .fr: "Pression mémoire passée à %@."
        ],
        "event.autoReleaseTrigger": [
            .en: "Auto cleanup trigger: %@.",
            .zhHans: "自动清理触发：%@。",
            .zhHant: "自動清理觸發：%@。",
            .ja: "自動整理トリガー：%@。",
            .de: "Automatische Bereinigung ausgelöst: %@.",
            .fr: "Déclenchement du nettoyage : %@."
        ],
        "event.backgroundIdleTimeout": [
            .en: "background time exceeded",
            .zhHans: "非前台时间已超过阈值",
            .zhHant: "非前台時間已超過閾值",
            .ja: "背景時間がしきい値を超過",
            .de: "Hintergrundzeit überschritten",
            .fr: "temps en arrière-plan dépassé"
        ],
        "event.systemPressure": [
            .en: "System pressure %@",
            .zhHans: "系统压力 %@",
            .zhHant: "系統壓力 %@",
            .ja: "システム圧力 %@",
            .de: "Systemdruck %@",
            .fr: "Pression système %@"
        ],
        "event.belowThresholds": [
            .en: "Below thresholds",
            .zhHans: "低于阈值",
            .zhHant: "低於閾值",
            .ja: "しきい値未満",
            .de: "Unter den Schwellen",
            .fr: "Sous les seuils"
        ],
        "event.autoReleaseEnabled": [
            .en: "Auto cleanup enabled.",
            .zhHans: "超限自动清理已开启。",
            .zhHant: "超限自動清理已開啟。",
            .ja: "自動整理を有効にしました。",
            .de: "Automatische Bereinigung aktiviert.",
            .fr: "Nettoyage automatique activé."
        ],
        "event.autoReleaseDisabled": [
            .en: "Auto cleanup disabled.",
            .zhHans: "超限自动清理已关闭。",
            .zhHant: "超限自動清理已關閉。",
            .ja: "自動整理を無効にしました。",
            .de: "Automatische Bereinigung deaktiviert.",
            .fr: "Nettoyage automatique désactivé."
        ],
        "event.aggressiveEnabled": [
            .en: "Aggressive force kill enabled.",
            .zhHans: "激进强杀已开启。",
            .zhHant: "激進強殺已開啟。",
            .ja: "強制終了モードを有効にしました。",
            .de: "Aggressives Beenden aktiviert.",
            .fr: "Fermeture forcée activée."
        ],
        "event.aggressiveDisabled": [
            .en: "Aggressive force kill disabled.",
            .zhHans: "激进强杀已关闭。",
            .zhHant: "激進強殺已關閉。",
            .ja: "強制終了モードを無効にしました。",
            .de: "Aggressives Beenden deaktiviert.",
            .fr: "Fermeture forcée désactivée."
        ],
        "event.manualRelease": [
            .en: "Manual eligible app cleanup requested.",
            .zhHans: "已手动清理可清理 App。",
            .zhHant: "已手動清理可清理 App。",
            .ja: "背景アプリの手動整理を要求しました。",
            .de: "Manuelle Bereinigung von Hintergrund-Apps angefordert.",
            .fr: "Nettoyage manuel des apps en arrière-plan demandé."
        ],
        "event.settingsUpdated": [
            .en: "Memory policy settings updated.",
            .zhHans: "内存策略设置已更新。",
            .zhHant: "記憶體策略設定已更新。",
            .ja: "メモリポリシー設定を更新しました。",
            .de: "Speicherrichtlinien aktualisiert.",
            .fr: "Réglages de politique mémoire mis à jour."
        ],
        "event.logsExported": [
            .en: "Logs exported to %@.",
            .zhHans: "日志已导出到 %@。",
            .zhHant: "日誌已匯出到 %@。",
            .ja: "ログを書き出しました：%@。",
            .de: "Protokolle exportiert nach %@.",
            .fr: "Journaux exportés vers %@."
        ],
        "event.logsExportFailed": [
            .en: "Log export failed: %@.",
            .zhHans: "日志导出失败：%@。",
            .zhHant: "日誌匯出失敗：%@。",
            .ja: "ログの書き出しに失敗しました：%@。",
            .de: "Protokollexport fehlgeschlagen: %@.",
            .fr: "Échec de l’export des journaux : %@."
        ],
        "event.addedWhitelist": [
            .en: "Added %@ to whitelist.",
            .zhHans: "已将 %@ 加入白名单。",
            .zhHant: "已將 %@ 加入白名單。",
            .ja: "%@ をホワイトリストに追加しました。",
            .de: "%@ zur Whitelist hinzugefügt.",
            .fr: "%@ ajoutée à la liste blanche."
        ],
        "event.removedWhitelist": [
            .en: "Removed %@ from whitelist.",
            .zhHans: "已从白名单移除 %@。",
            .zhHant: "已從白名單移除 %@。",
            .ja: "%@ をホワイトリストから削除しました。",
            .de: "%@ aus der Whitelist entfernt.",
            .fr: "%@ retirée de la liste blanche."
        ],
        "event.autoReleaseDisabledIgnored": [
            .en: "Auto cleanup is disabled; cleanup event ignored.",
            .zhHans: "自动清理已关闭；忽略清理事件。",
            .zhHant: "自動清理已關閉；忽略清理事件。",
            .ja: "自動整理が無効なため整理イベントを無視しました。",
            .de: "Automatische Bereinigung deaktiviert; Ereignis ignoriert.",
            .fr: "Nettoyage automatique désactivé ; événement ignoré."
        ],
        "event.noEligibleApps": [
            .en: "No cleanable apps.",
            .zhHans: "没有可清理 App。",
            .zhHant: "沒有可清理 App。",
            .ja: "対象のバックグラウンドアプリはありません。",
            .de: "Keine geeigneten Hintergrund-Apps.",
            .fr: "Aucune app admissible en arrière-plan."
        ],
        "event.skippedNoProcess": [
            .en: "Skipped %@: process no longer exists.",
            .zhHans: "已跳过 %@：进程不存在。",
            .zhHant: "已略過 %@：行程不存在。",
            .ja: "%@ をスキップ：プロセスが存在しません。",
            .de: "%@ übersprungen: Prozess existiert nicht mehr.",
            .fr: "%@ ignorée : processus introuvable."
        ],
        "event.requestedQuit": [
            .en: "Requested quit for %@ (%@).",
            .zhHans: "已请求退出 %@（%@）。",
            .zhHant: "已請求退出 %@（%@）。",
            .ja: "%@ の終了を要求しました（%@）。",
            .de: "Beenden von %@ angefordert (%@).",
            .fr: "Fermeture demandée pour %@ (%@)."
        ],
        "event.quitFailed": [
            .en: "Quit request failed for %@.",
            .zhHans: "请求退出 %@ 失败。",
            .zhHant: "請求退出 %@ 失敗。",
            .ja: "%@ の終了要求に失敗しました。",
            .de: "Beenden von %@ fehlgeschlagen.",
            .fr: "Échec de fermeture pour %@."
        ],
        "event.forceTerminated": [
            .en: "Force terminated %@.",
            .zhHans: "已强制清理 %@。",
            .zhHant: "已強制清理 %@。",
            .ja: "%@ を強制終了しました。",
            .de: "%@ wurde erzwungen beendet.",
            .fr: "%@ a été forcée à quitter."
        ],
        "event.forceTerminateFailed": [
            .en: "Force terminate failed for %@.",
            .zhHans: "强制清理 %@ 失败。",
            .zhHant: "強制清理 %@ 失敗。",
            .ja: "%@ の強制終了に失敗しました。",
            .de: "Erzwungenes Beenden von %@ fehlgeschlagen.",
            .fr: "Échec de fermeture forcée pour %@."
        ],
        "event.idleChildProcessesTerminated": [
            .en: "Cleaned idle child processes of %@: %d processes, %@, %@ — %@",
            .zhHans: "已清理 %@ 的闲置子进程：%d 个，%@，%@ — %@",
            .zhHant: "已清理 %@ 的閒置子行程：%d 個，%@，%@ — %@",
            .ja: "%@ のアイドル子プロセスを終了しました：%d 個、%@、%@ — %@",
            .de: "Inaktive Kindprozesse von %@ beendet: %d Prozesse, %@, %@ — %@",
            .fr: "Processus enfants inactifs de %@ arrêtés : %d processus, %@, %@ — %@"
        ],
        "event.idleChildProcessesTerminateFailed": [
            .en: "Failed to clean idle child processes of %@: %@",
            .zhHans: "清理 %@ 的闲置子进程失败：%@",
            .zhHant: "清理 %@ 的閒置子行程失敗：%@",
            .ja: "%@ のアイドル子プロセスの終了に失敗しました：%@",
            .de: "Beenden inaktiver Kindprozesse von %@ fehlgeschlagen: %@",
            .fr: "Échec de l’arrêt des processus enfants inactifs de %@ : %@"
        ],
        "trigger.ramThreshold": [
            .en: "RAM %@ >= %@",
            .zhHans: "物理内存 %@ >= %@",
            .zhHant: "實體記憶體 %@ >= %@",
            .ja: "RAM %@ >= %@",
            .de: "RAM %@ >= %@",
            .fr: "RAM %@ >= %@"
        ],
        "trigger.swapThreshold": [
            .en: "Swap %@ >= %@",
            .zhHans: "交换内存 %@ >= %@",
            .zhHant: "交換記憶體 %@ >= %@",
            .ja: "スワップ %@ >= %@",
            .de: "Auslagerung %@ >= %@",
            .fr: "Swap %@ >= %@"
        ],
        "sidebar.monitor": [
            .en: "Monitor",
            .zhHans: "监控",
            .zhHant: "監控",
            .ja: "モニタ",
            .de: "Überwachung",
            .fr: "Surveillance"
        ],
        "sidebar.overview": [
            .en: "Overview",
            .zhHans: "概览",
            .zhHant: "概覽",
            .ja: "概要",
            .de: "Übersicht",
            .fr: "Vue d’ensemble"
        ],
        "sidebar.settings": [
            .en: "Settings",
            .zhHans: "设置",
            .zhHant: "設定",
            .ja: "設定",
            .de: "Einstellungen",
            .fr: "Réglages"
        ],
        "status.foreground": [
            .en: "Foreground",
            .zhHans: "前台",
            .zhHant: "前台",
            .ja: "最前面",
            .de: "Vordergrund",
            .fr: "Premier plan"
        ],
        "status.monitoring": [
            .en: "Monitoring",
            .zhHans: "监控中",
            .zhHant: "監控中",
            .ja: "監視中",
            .de: "Beobachtet",
            .fr: "Surveillée"
        ],
        "overview.subtitle": [
            .en: "%d apps · updated %@",
            .zhHans: "%d 个 App · 更新于 %@",
            .zhHant: "%d 個 App · 更新於 %@",
            .ja: "%d 個のアプリ · %@ に更新",
            .de: "%d Apps · aktualisiert um %@",
            .fr: "%d apps · mis à jour à %@"
        ],
        "overview.ramUsedPercent": [
            .en: "%@ in use",
            .zhHans: "已使用 %@",
            .zhHant: "已使用 %@",
            .ja: "%@ 使用中",
            .de: "%@ belegt",
            .fr: "%@ utilisée"
        ],
        "overview.swapLimitOff": [
            .en: "No Swap limit",
            .zhHans: "未启用 Swap 限制",
            .zhHant: "未啟用 Swap 限制",
            .ja: "Swap 上限なし",
            .de: "Kein Swap-Limit",
            .fr: "Aucune limite de swap"
        ],
        "overview.noCleanableApps": [
            .en: "Nothing to clean",
            .zhHans: "暂无可清理 App",
            .zhHant: "暫無可清理 App",
            .ja: "クリーンアップ対象なし",
            .de: "Nichts zu bereinigen",
            .fr: "Rien à nettoyer"
        ],
        "overview.totalMemory": [
            .en: "%@ in total",
            .zhHans: "合计 %@",
            .zhHant: "合計 %@",
            .ja: "合計 %@",
            .de: "Insgesamt %@",
            .fr: "%@ au total"
        ],
        "overview.idleChildProcesses": [
            .en: "Idle Process Groups",
            .zhHans: "闲置子进程组",
            .zhHant: "閒置子行程組",
            .ja: "アイドル子プロセス群",
            .de: "Inaktive Prozessgruppen",
            .fr: "Groupes inactifs"
        ],
        "overview.noIdleChildProcesses": [
            .en: "None idle",
            .zhHans: "暂无闲置",
            .zhHant: "暫無閒置",
            .ja: "なし",
            .de: "Keine inaktiv",
            .fr: "Aucun inactif"
        ],
        "overview.composition": [
            .en: "Memory Composition",
            .zhHans: "内存构成",
            .zhHant: "記憶體構成",
            .ja: "メモリ構成",
            .de: "Speicheraufteilung",
            .fr: "Composition de la mémoire"
        ],
        "overview.compositionHint": [
            .en: "%@ physical memory · same categories as Activity Monitor",
            .zhHans: "共 %@ 物理内存 · 口径与活动监视器一致",
            .zhHant: "共 %@ 實體記憶體 · 口徑與活動監視器一致",
            .ja: "物理メモリ %@ · アクティビティモニタと同じ分類",
            .de: "%@ physischer Speicher · Kategorien wie in der Aktivitätsanzeige",
            .fr: "%@ de mémoire physique · mêmes catégories que le Moniteur d’activité"
        ],
        "overview.treemap": [
            .en: "App Memory Map",
            .zhHans: "App 内存平铺",
            .zhHant: "App 記憶體平鋪",
            .ja: "アプリのメモリマップ",
            .de: "App-Speicherkarte",
            .fr: "Carte mémoire des apps"
        ],
        "overview.treemapHint": [
            .en: "%d apps · %@ · area = whole process tree incl. child processes · click a tile for details",
            .zhHans: "%d 个 App · 合计 %@ · 面积为整个进程树（含子进程）· 点击查看详情",
            .zhHant: "%d 個 App · 合計 %@ · 面積為整個行程樹（含子行程）· 點按查看詳情",
            .ja: "%d 個のアプリ · 合計 %@ · 面積は子プロセスを含むプロセスツリー全体 · クリックで詳細",
            .de: "%d Apps · %@ · Fläche = gesamter Prozessbaum inkl. Kindprozessen · Klicken für Details",
            .fr: "%d apps · %@ · surface = arbre de processus complet, enfants compris · cliquez pour les détails"
        ],
        "overview.cleanNowHint": [
            .en: "Force quit apps that currently meet the cleanup rules",
            .zhHans: "强制退出当前符合清理条件的 App",
            .zhHant: "強制退出目前符合清理條件的 App",
            .ja: "現在クリーンアップ条件を満たすアプリを強制終了します",
            .de: "Apps sofort beenden, die die Bereinigungsregeln erfüllen",
            .fr: "Forcer à quitter les apps qui remplissent les règles de nettoyage"
        ],
        "composition.app": [
            .en: "App Memory",
            .zhHans: "App 内存",
            .zhHant: "App 記憶體",
            .ja: "アプリメモリ",
            .de: "App-Speicher",
            .fr: "Mémoire des apps"
        ],
        "composition.wired": [
            .en: "Wired",
            .zhHans: "联动内存",
            .zhHant: "聯動記憶體",
            .ja: "確保されているメモリ",
            .de: "Fest belegt",
            .fr: "Mémoire résidente"
        ],
        "composition.compressed": [
            .en: "Compressed",
            .zhHans: "已压缩",
            .zhHant: "已壓縮",
            .ja: "圧縮",
            .de: "Komprimiert",
            .fr: "Compressée"
        ],
        "composition.cached": [
            .en: "Cached Files",
            .zhHans: "缓存文件",
            .zhHant: "快取檔案",
            .ja: "キャッシュされたファイル",
            .de: "Zwischengespeichert",
            .fr: "Fichiers en cache"
        ],
        "composition.free": [
            .en: "Free",
            .zhHans: "可用",
            .zhHant: "可用",
            .ja: "空き",
            .de: "Frei",
            .fr: "Libre"
        ],
        "treemap.otherApps": [
            .en: "%d other apps",
            .zhHans: "其他 %d 个 App",
            .zhHant: "其他 %d 個 App",
            .ja: "その他 %d 個のアプリ",
            .de: "%d weitere Apps",
            .fr: "%d autres apps"
        ],
        "apps.subtitle": [
            .en: "%d running apps · %@ in total, including child processes",
            .zhHans: "%d 个运行中的 App · 合计 %@（含子进程）",
            .zhHant: "%d 個執行中的 App · 合計 %@（含子行程）",
            .ja: "実行中のアプリ %d 個 · 合計 %@（子プロセスを含む）",
            .de: "%d laufende Apps · insgesamt %@ inkl. Kindprozessen",
            .fr: "%d apps ouvertes · %@ au total, processus enfants compris"
        ],
        "apps.filterAll": [
            .en: "All",
            .zhHans: "全部",
            .zhHant: "全部",
            .ja: "すべて",
            .de: "Alle",
            .fr: "Toutes"
        ],
        "apps.filterAutoQuit": [
            .en: "Auto-Quit",
            .zhHans: "超时自动关闭",
            .zhHant: "逾時自動關閉",
            .ja: "自動終了",
            .de: "Auto-Beenden",
            .fr: "Auto-fermeture"
        ],
        "apps.search": [
            .en: "Search apps",
            .zhHans: "搜索 App",
            .zhHant: "搜尋 App",
            .ja: "アプリを検索",
            .de: "Apps suchen",
            .fr: "Rechercher des apps"
        ],
        "apps.empty": [
            .en: "No matching apps",
            .zhHans: "没有匹配的 App",
            .zhHant: "沒有符合的 App",
            .ja: "一致するアプリはありません",
            .de: "Keine passenden Apps",
            .fr: "Aucune app correspondante"
        ],
        "apps.addAutoQuit": [
            .en: "Add to Auto-Quit Apps",
            .zhHans: "加入超时自动关闭",
            .zhHant: "加入逾時自動關閉",
            .ja: "自動終了するアプリに追加",
            .de: "Automatisch beenden",
            .fr: "Ajouter à l’auto-fermeture"
        ],
        "apps.removeAutoQuit": [
            .en: "Remove from Auto-Quit Apps",
            .zhHans: "移出超时自动关闭",
            .zhHant: "移出逾時自動關閉",
            .ja: "自動終了するアプリから削除",
            .de: "Nicht mehr automatisch beenden",
            .fr: "Retirer de l’auto-fermeture"
        ],
        "apps.ownApp": [
            .en: "GreenRAM itself, never cleaned",
            .zhHans: "GreenRAM 自身，永不清理",
            .zhHant: "GreenRAM 本身，永不清理",
            .ja: "GreenRAM 自身（クリーンアップされません）",
            .de: "GreenRAM selbst, wird nie bereinigt",
            .fr: "GreenRAM lui-même, jamais nettoyé"
        ],
        "apps.backgroundProgress": [
            .en: "Background %@ / threshold %@",
            .zhHans: "后台 %@ / 阈值 %@",
            .zhHant: "後台 %@ / 閾值 %@",
            .ja: "バックグラウンド %@ / しきい値 %@",
            .de: "Hintergrund %@ / Schwelle %@",
            .fr: "Arrière-plan %@ / seuil %@"
        ],
        "apps.memoryLimit": [
            .en: "Limit %@",
            .zhHans: "上限 %@",
            .zhHant: "上限 %@",
            .ja: "上限 %@",
            .de: "Limit %@",
            .fr: "Limite %@"
        ],
        "apps.childProcesses": [
            .en: "%d child processes · %@ in total",
            .zhHans: "%d 个子进程 · 合计 %@",
            .zhHant: "%d 個子行程 · 合計 %@",
            .ja: "子プロセス %d 個 · 合計 %@",
            .de: "%d Kindprozesse · insgesamt %@",
            .fr: "%d processus enfants · %@ au total"
        ],
        "duration.seconds": [
            .en: "%d s",
            .zhHans: "%d 秒",
            .zhHant: "%d 秒",
            .ja: "%d 秒",
            .de: "%d s",
            .fr: "%d s"
        ],
        "duration.minutes": [
            .en: "%d min",
            .zhHans: "%d 分钟",
            .zhHant: "%d 分鐘",
            .ja: "%d 分",
            .de: "%d Min.",
            .fr: "%d min"
        ],
        "duration.hours": [
            .en: "%.1f h",
            .zhHans: "%.1f 小时",
            .zhHant: "%.1f 小時",
            .ja: "%.1f 時間",
            .de: "%.1f Std.",
            .fr: "%.1f h"
        ],
        "panel.openMainWindow": [
            .en: "Open GreenRAM Window",
            .zhHans: "打开 GreenRAM 主窗口",
            .zhHant: "打開 GreenRAM 主視窗",
            .ja: "GreenRAM のウインドウを開く",
            .de: "GreenRAM-Fenster öffnen",
            .fr: "Ouvrir la fenêtre GreenRAM"
        ],
        "panel.topApps": [
            .en: "Top Memory",
            .zhHans: "占用最高",
            .zhHant: "佔用最高",
            .ja: "メモリ使用量上位",
            .de: "Größter Speicherbedarf",
            .fr: "Plus gourmandes"
        ],
        "panel.allApps": [
            .en: "All %d apps",
            .zhHans: "全部 %d 个",
            .zhHant: "全部 %d 個",
            .ja: "全 %d 個",
            .de: "Alle %d Apps",
            .fr: "Les %d apps"
        ],
        "panel.summary": [
            .en: "%d cleanable apps · %d idle child process groups",
            .zhHans: "可清理 %d 个 App · 闲置子进程 %d 组",
            .zhHant: "可清理 %d 個 App · 閒置子行程 %d 組",
            .ja: "クリーンアップ可 %d 個 · アイドル子プロセス %d 群",
            .de: "%d bereinigbare Apps · %d inaktive Prozessgruppen",
            .fr: "%d apps nettoyables · %d groupes de processus inactifs"
        ],
        "settings.whitelistHint": [
            .en: "Whitelisted apps are never quit. Finder, Dock and other system items are included by default and can be removed.",
            .zhHans: "白名单 App 永不清理。Finder、Dock 等系统项默认在内，也可以移除。",
            .zhHant: "白名單 App 永不清理。Finder、Dock 等系統項預設在內，也可以移除。",
            .ja: "ホワイトリストのアプリは終了されません。Finder や Dock などのシステム項目は初期状態で含まれ、削除もできます。",
            .de: "Apps auf der Whitelist werden nie beendet. Finder, Dock und andere Systemobjekte sind vorab eingetragen und lassen sich entfernen.",
            .fr: "Les apps de la liste blanche ne sont jamais fermées. Finder, Dock et d’autres éléments système y figurent par défaut et peuvent être retirés."
        ],
        "settings.onboarding": [
            .en: "Welcome Guide",
            .zhHans: "引导页",
            .zhHant: "引導頁",
            .ja: "ようこそガイド",
            .de: "Einführung",
            .fr: "Guide de bienvenue"
        ],
        "settings.onboardingHint": [
            .en: "How GreenRAM decides what to clean",
            .zhHans: "介绍 GreenRAM 如何决定清理哪些 App",
            .zhHant: "介紹 GreenRAM 如何決定清理哪些 App",
            .ja: "GreenRAM がクリーンアップ対象を決める仕組み",
            .de: "Wie GreenRAM entscheidet, was bereinigt wird",
            .fr: "Comment GreenRAM choisit quoi nettoyer"
        ],
        "settings.showOnboarding": [
            .en: "Show Again",
            .zhHans: "再次显示",
            .zhHant: "再次顯示",
            .ja: "もう一度表示",
            .de: "Erneut anzeigen",
            .fr: "Afficher à nouveau"
        ],
        "mainMenu.about": [
            .en: "About %@",
            .zhHans: "关于 %@",
            .zhHant: "關於 %@",
            .ja: "%@ について",
            .de: "Über %@",
            .fr: "À propos de %@"
        ],
        "mainMenu.hide": [
            .en: "Hide %@",
            .zhHans: "隐藏 %@",
            .zhHant: "隱藏 %@",
            .ja: "%@ を非表示",
            .de: "%@ ausblenden",
            .fr: "Masquer %@"
        ],
        "mainMenu.hideOthers": [
            .en: "Hide Others",
            .zhHans: "隐藏其他",
            .zhHant: "隱藏其他",
            .ja: "ほかを非表示",
            .de: "Andere ausblenden",
            .fr: "Masquer les autres"
        ],
        "mainMenu.showAll": [
            .en: "Show All",
            .zhHans: "全部显示",
            .zhHant: "顯示全部",
            .ja: "すべてを表示",
            .de: "Alle einblenden",
            .fr: "Tout afficher"
        ],
        "mainMenu.quit": [
            .en: "Quit %@",
            .zhHans: "退出 %@",
            .zhHant: "結束 %@",
            .ja: "%@ を終了",
            .de: "%@ beenden",
            .fr: "Quitter %@"
        ],
        "mainMenu.edit": [
            .en: "Edit",
            .zhHans: "编辑",
            .zhHant: "編輯",
            .ja: "編集",
            .de: "Bearbeiten",
            .fr: "Édition"
        ],
        "mainMenu.undo": [
            .en: "Undo",
            .zhHans: "撤销",
            .zhHant: "還原",
            .ja: "取り消す",
            .de: "Widerrufen",
            .fr: "Annuler"
        ],
        "mainMenu.redo": [
            .en: "Redo",
            .zhHans: "重做",
            .zhHant: "重做",
            .ja: "やり直す",
            .de: "Wiederholen",
            .fr: "Rétablir"
        ],
        "mainMenu.cut": [
            .en: "Cut",
            .zhHans: "剪切",
            .zhHant: "剪下",
            .ja: "カット",
            .de: "Ausschneiden",
            .fr: "Couper"
        ],
        "mainMenu.copy": [
            .en: "Copy",
            .zhHans: "拷贝",
            .zhHant: "拷貝",
            .ja: "コピー",
            .de: "Kopieren",
            .fr: "Copier"
        ],
        "mainMenu.paste": [
            .en: "Paste",
            .zhHans: "粘贴",
            .zhHant: "貼上",
            .ja: "ペースト",
            .de: "Einsetzen",
            .fr: "Coller"
        ],
        "mainMenu.selectAll": [
            .en: "Select All",
            .zhHans: "全选",
            .zhHant: "全選",
            .ja: "すべてを選択",
            .de: "Alles auswählen",
            .fr: "Tout sélectionner"
        ],
        "mainMenu.window": [
            .en: "Window",
            .zhHans: "窗口",
            .zhHant: "視窗",
            .ja: "ウインドウ",
            .de: "Fenster",
            .fr: "Fenêtre"
        ],
        "mainMenu.mainWindow": [
            .en: "GreenRAM Window",
            .zhHans: "GreenRAM 主窗口",
            .zhHant: "GreenRAM 主視窗",
            .ja: "GreenRAM ウインドウ",
            .de: "GreenRAM-Fenster",
            .fr: "Fenêtre GreenRAM"
        ],
        "mainMenu.minimize": [
            .en: "Minimize",
            .zhHans: "最小化",
            .zhHant: "縮到最小",
            .ja: "しまう",
            .de: "Im Dock ablegen",
            .fr: "Placer dans le Dock"
        ],
        "mainMenu.zoom": [
            .en: "Zoom",
            .zhHans: "缩放",
            .zhHant: "縮放",
            .ja: "拡大/縮小",
            .de: "Zoomen",
            .fr: "Réduire/agrandir"
        ],
        "mainMenu.close": [
            .en: "Close",
            .zhHans: "关闭",
            .zhHant: "關閉",
            .ja: "閉じる",
            .de: "Schließen",
            .fr: "Fermer"
        ],
        "onboarding.back": [
            .en: "Back",
            .zhHans: "上一步",
            .zhHant: "上一步",
            .ja: "戻る",
            .de: "Zurück",
            .fr: "Retour"
        ],
        "onboarding.continue": [
            .en: "Continue",
            .zhHans: "继续",
            .zhHant: "繼續",
            .ja: "続ける",
            .de: "Weiter",
            .fr: "Continuer"
        ],
        "onboarding.start": [
            .en: "Start Using GreenRAM",
            .zhHans: "开始使用",
            .zhHant: "開始使用",
            .ja: "使い始める",
            .de: "Loslegen",
            .fr: "Commencer"
        ],
        "onboarding.welcomeTitle": [
            .en: "Welcome to GreenRAM",
            .zhHans: "欢迎使用 GreenRAM",
            .zhHant: "歡迎使用 GreenRAM",
            .ja: "GreenRAM へようこそ",
            .de: "Willkommen bei GreenRAM",
            .fr: "Bienvenue dans GreenRAM"
        ],
        "onboarding.welcomeMessage": [
            .en: "GreenRAM lives in the menu bar, watches memory, and quits background apps that have been idle too long by clear rules, so the app in front stays fast.",
            .zhHans: "GreenRAM 常驻菜单栏，观察内存状态，按清晰的规则退出闲置太久的后台 App，让前台保持流畅。",
            .zhHant: "GreenRAM 常駐選單列，觀察記憶體狀態，依明確規則退出閒置太久的後台 App，讓前台保持流暢。",
            .ja: "GreenRAM はメニューバーに常駐してメモリを監視し、長くアイドル状態のバックグラウンドアプリを明確なルールで終了して、手前のアプリを快適に保ちます。",
            .de: "GreenRAM sitzt in der Menüleiste, beobachtet den Speicher und beendet nach klaren Regeln Hintergrund-Apps, die zu lange inaktiv sind – damit die App im Vordergrund flüssig bleibt.",
            .fr: "GreenRAM réside dans la barre des menus, surveille la mémoire et ferme selon des règles claires les apps restées trop longtemps inactives en arrière-plan, pour que l’app au premier plan reste fluide."
        ],
        "onboarding.insightTitle": [
            .en: "See where memory goes",
            .zhHans: "看清内存去向",
            .zhHant: "看清記憶體去向",
            .ja: "メモリの行き先がわかる",
            .de: "Sehen, wohin der Speicher geht",
            .fr: "Voir où part la mémoire"
        ],
        "onboarding.insightDetail": [
            .en: "The main window lays out every app and the child processes it started.",
            .zhHans: "主窗口平铺展示每个 App 以及它拉起的子进程占用的内存。",
            .zhHant: "主視窗平鋪展示每個 App 及其啟動的子行程所佔用的記憶體。",
            .ja: "メインウインドウに、すべてのアプリとその子プロセスのメモリを並べて表示します。",
            .de: "Das Hauptfenster zeigt jede App samt ihrer Kindprozesse auf einen Blick.",
            .fr: "La fenêtre principale affiche chaque app et les processus enfants qu’elle a lancés."
        ],
        "onboarding.cleanTitle": [
            .en: "Clean by rules",
            .zhHans: "按规则清理",
            .zhHant: "依規則清理",
            .ja: "ルールでクリーンアップ",
            .de: "Nach Regeln bereinigen",
            .fr: "Nettoyer selon des règles"
        ],
        "onboarding.cleanDetail": [
            .en: "Background apps are force quit only when their rule is met. The frontmost app and whitelisted apps are never touched.",
            .zhHans: "只有满足规则时才强制退出后台 App。前台 App 和白名单 App 永远不会被退出。",
            .zhHant: "只有符合規則時才強制退出後台 App。前台 App 和白名單 App 永遠不會被退出。",
            .ja: "ルールを満たしたときだけバックグラウンドアプリを強制終了します。最前面のアプリとホワイトリストのアプリは終了しません。",
            .de: "Hintergrund-Apps werden nur beendet, wenn ihre Regel erfüllt ist. Die App im Vordergrund und Apps auf der Whitelist bleiben unberührt.",
            .fr: "Les apps en arrière-plan ne sont forcées à quitter que si leur règle est remplie. L’app au premier plan et la liste blanche ne sont jamais touchées."
        ],
        "onboarding.childTitle": [
            .en: "Reclaim idle child processes",
            .zhHans: "回收闲置子进程",
            .zhHant: "回收閒置子行程",
            .ja: "アイドル子プロセスを回収",
            .de: "Inaktive Kindprozesse freigeben",
            .fr: "Récupérer les processus enfants inactifs"
        ],
        "onboarding.childDetail": [
            .en: "Language servers, MCP servers and other CLI tools left idle under an app are ended without quitting the app.",
            .zhHans: "App 名下长期闲置的语言服务器、MCP server 等命令行工具会被结束，App 本身不退出。",
            .zhHant: "App 名下長期閒置的語言伺服器、MCP server 等命令列工具會被結束，App 本身不退出。",
            .ja: "アプリの下で放置された言語サーバや MCP サーバなどの CLI ツールを、アプリを終了せずに止めます。",
            .de: "Language Server, MCP-Server und andere CLI-Tools, die unter einer App ungenutzt laufen, werden beendet – die App selbst bleibt offen.",
            .fr: "Les serveurs de langage, serveurs MCP et autres outils en ligne de commande inactifs sous une app sont arrêtés, sans fermer l’app."
        ],
        "onboarding.rulesTitle": [
            .en: "Cleanup Rules",
            .zhHans: "清理规则",
            .zhHant: "清理規則",
            .ja: "クリーンアップのルール",
            .de: "Bereinigungsregeln",
            .fr: "Règles de nettoyage"
        ],
        "onboarding.rulesMessage": [
            .en: "The timer starts when an app leaves the foreground (%d minutes by default). After that, the app’s rule decides whether it is quit.",
            .zhHans: "App 离开前台后开始计时，默认 %d 分钟。到点之后，按 App 所属的规则决定是否退出。",
            .zhHant: "App 離開前台後開始計時，預設 %d 分鐘。到時間後，依 App 所屬的規則決定是否退出。",
            .ja: "アプリが最前面から外れるとタイマーが始まります（初期値 %d 分）。時間が来たら、そのアプリのルールで終了するか決まります。",
            .de: "Die Zeit läuft, sobald eine App den Vordergrund verlässt (standardmäßig %d Minuten). Danach entscheidet die Regel der App, ob sie beendet wird.",
            .fr: "Le minuteur démarre quand une app quitte le premier plan (%d minutes par défaut). Ensuite, la règle de l’app décide si elle est fermée."
        ],
        "onboarding.whitelistDetail": [
            .en: "Never quit. Finder, Dock and other system items are included by default and can be edited.",
            .zhHans: "永不清理。Finder、Dock 等系统项默认在内，可以随时编辑。",
            .zhHant: "永不清理。Finder、Dock 等系統項預設在內，可隨時編輯。",
            .ja: "終了しません。Finder や Dock などのシステム項目が初期状態で含まれ、いつでも編集できます。",
            .de: "Wird nie beendet. Finder, Dock und andere Systemobjekte sind vorab eingetragen und jederzeit änderbar.",
            .fr: "Jamais fermées. Finder, Dock et d’autres éléments système y figurent par défaut et restent modifiables."
        ],
        "onboarding.autoQuitDetail": [
            .en: "Quit as soon as the background time is reached, without waiting for RAM or Swap limits.",
            .zhHans: "非前台时间一到就退出，不等 RAM 或 Swap 超限。",
            .zhHant: "非前台時間一到就退出，不等 RAM 或 Swap 超限。",
            .ja: "バックグラウンド時間に達したらすぐ終了し、RAM や Swap の超過を待ちません。",
            .de: "Werden beendet, sobald die Hintergrundzeit erreicht ist – ohne auf RAM- oder Swap-Limits zu warten.",
            .fr: "Fermées dès que le temps en arrière-plan est atteint, sans attendre les limites de RAM ou de swap."
        ],
        "onboarding.ordinaryTitle": [
            .en: "Other Apps",
            .zhHans: "普通 App",
            .zhHant: "一般 App",
            .ja: "その他のアプリ",
            .de: "Andere Apps",
            .fr: "Autres apps"
        ],
        "onboarding.ordinaryDetail": [
            .en: "Quit only after the background time, and only when system memory is over the limit or the app exceeds its own memory limit.",
            .zhHans: "非前台时间到点，并且系统内存超限或该 App 超过自己的内存上限，才会退出。",
            .zhHant: "非前台時間到，且系統記憶體超限或該 App 超過自身記憶體上限，才會退出。",
            .ja: "バックグラウンド時間に達し、さらにシステムメモリが上限を超えるか、アプリ自身のメモリ上限を超えたときだけ終了します。",
            .de: "Werden erst nach Ablauf der Hintergrundzeit beendet – und nur, wenn der Systemspeicher das Limit überschreitet oder die App ihr eigenes Speicherlimit erreicht.",
            .fr: "Fermées seulement après le temps en arrière-plan, et seulement si la mémoire système dépasse la limite ou si l’app dépasse sa propre limite."
        ],
        "onboarding.childRuleTitle": [
            .en: "Idle Child Processes",
            .zhHans: "闲置子进程",
            .zhHant: "閒置子行程",
            .ja: "アイドル子プロセス",
            .de: "Inaktive Kindprozesse",
            .fr: "Processus enfants inactifs"
        ],
        "onboarding.childRuleDetail": [
            .en: "External child process groups idle for %d minutes and using %@ or more are ended. The app itself keeps running.",
            .zhHans: "外部子进程组闲置 %d 分钟且合计达到 %@ 时被结束，App 本身继续运行。",
            .zhHant: "外部子行程組閒置 %d 分鐘且合計達到 %@ 時會被結束，App 本身繼續執行。",
            .ja: "%d 分間アイドルで合計 %@ 以上の外部子プロセス群を終了します。アプリ自体は動き続けます。",
            .de: "Externe Kindprozessgruppen, die %d Minuten inaktiv sind und zusammen mindestens %@ belegen, werden beendet. Die App läuft weiter.",
            .fr: "Les groupes de processus enfants externes inactifs depuis %d minutes et utilisant au moins %@ sont arrêtés. L’app continue de tourner."
        ],
        "onboarding.readyTitle": [
            .en: "You’re All Set",
            .zhHans: "准备就绪",
            .zhHant: "準備就緒",
            .ja: "準備完了",
            .de: "Alles bereit",
            .fr: "Tout est prêt"
        ],
        "onboarding.readyMessage": [
            .en: "GreenRAM is already working. Rules and thresholds can be changed any time in the main window.",
            .zhHans: "GreenRAM 已经开始工作。规则和阈值随时可以在主窗口里调整。",
            .zhHant: "GreenRAM 已開始運作。規則和閾值隨時可以在主視窗中調整。",
            .ja: "GreenRAM はすでに動作しています。ルールやしきい値はメインウインドウでいつでも変更できます。",
            .de: "GreenRAM arbeitet bereits. Regeln und Schwellen lassen sich jederzeit im Hauptfenster ändern.",
            .fr: "GreenRAM est déjà au travail. Règles et seuils se modifient à tout moment dans la fenêtre principale."
        ],
        "onboarding.menuBarTitle": [
            .en: "The menu bar leaf",
            .zhHans: "菜单栏叶子",
            .zhHant: "選單列葉子",
            .ja: "メニューバーの葉",
            .de: "Das Blatt in der Menüleiste",
            .fr: "La feuille dans la barre des menus"
        ],
        "onboarding.menuBarDetail": [
            .en: "Green means memory is within limits, red means over the limit. Click it for live status and quick actions.",
            .zhHans: "绿色表示内存正常，红色表示已超限。点击查看实时状态和常用操作。",
            .zhHant: "綠色表示記憶體正常，紅色表示已超限。點按查看即時狀態和常用操作。",
            .ja: "緑はメモリが範囲内、赤は上限超過を示します。クリックするとリアルタイムの状態とよく使う操作が表示されます。",
            .de: "Grün heißt Speicher im Limit, rot heißt Limit überschritten. Ein Klick zeigt Live-Status und Schnellaktionen.",
            .fr: "Vert : mémoire dans les limites ; rouge : limite dépassée. Cliquez pour l’état en direct et les actions rapides."
        ],
        "onboarding.mainWindowTitle": [
            .en: "The main window",
            .zhHans: "主窗口",
            .zhHant: "主視窗",
            .ja: "メインウインドウ",
            .de: "Das Hauptfenster",
            .fr: "La fenêtre principale"
        ],
        "onboarding.mainWindowDetail": [
            .en: "Open it from the menu bar panel or the Dock to see all apps, rules and events.",
            .zhHans: "从菜单栏面板或 Dock 打开，查看全部 App、规则和事件。",
            .zhHant: "從選單列面板或 Dock 打開，查看全部 App、規則和事件。",
            .ja: "メニューバーのパネルや Dock から開き、すべてのアプリ、ルール、イベントを確認できます。",
            .de: "Über das Menüleisten-Panel oder das Dock öffnen, um alle Apps, Regeln und Ereignisse zu sehen.",
            .fr: "Ouvrez-la depuis le panneau de la barre des menus ou le Dock pour voir apps, règles et événements."
        ],
        "onboarding.defaultsTitle": [
            .en: "Defaults",
            .zhHans: "默认设置",
            .zhHant: "預設設定",
            .ja: "既定の設定",
            .de: "Standardwerte",
            .fr: "Réglages par défaut"
        ],
        "onboarding.defaultsDetail": [
            .en: "%d minutes in background, Swap limit %@, at most %d apps per cleanup round.",
            .zhHans: "后台 %d 分钟、Swap 上限 %@、每轮最多清理 %d 个 App。",
            .zhHant: "後台 %d 分鐘、Swap 上限 %@、每輪最多清理 %d 個 App。",
            .ja: "バックグラウンド %d 分、Swap 上限 %@、1 回のクリーンアップは最大 %d 個のアプリ。",
            .de: "%d Minuten im Hintergrund, Swap-Limit %@, höchstens %d Apps pro Bereinigungsrunde.",
            .fr: "%d minutes en arrière-plan, limite de swap %@, au plus %d apps par passage."
        ],
        "apps.forceQuit": [
            .en: "Force Quit %@",
            .zhHans: "强制退出 %@",
            .zhHant: "強制結束 %@",
            .ja: "%@ を強制終了",
            .de: "%@ sofort beenden",
            .fr: "Forcer %@ à quitter"
        ],
        "apps.forceQuitConfirmTitle": [
            .en: "Force quit “%@”?",
            .zhHans: "强制退出“%@”？",
            .zhHant: "強制結束「%@」？",
            .ja: "“%@”を強制終了しますか？",
            .de: "„%@“ sofort beenden?",
            .fr: "Forcer « %@ » à quitter ?"
        ],
        "apps.forceQuitConfirmMessage": [
            .en: "Unsaved changes in the app will be lost.",
            .zhHans: "该 App 中未保存的内容会丢失。",
            .zhHant: "該 App 中未儲存的內容會遺失。",
            .ja: "アプリ内の保存されていない変更は失われます。",
            .de: "Nicht gesicherte Änderungen in der App gehen verloren.",
            .fr: "Les modifications non enregistrées dans l’app seront perdues."
        ],
        "apps.forceQuitButton": [
            .en: "Force Quit",
            .zhHans: "强制退出",
            .zhHant: "強制結束",
            .ja: "強制終了",
            .de: "Sofort beenden",
            .fr: "Forcer à quitter"
        ],
        "event.manualForceQuit": [
            .en: "Manual force quit requested for %@.",
            .zhHans: "手动强制退出 %@。",
            .zhHant: "手動強制結束 %@。",
            .ja: "%@ の強制終了を手動で要求しました。",
            .de: "Sofortiges Beenden von %@ manuell angefordert.",
            .fr: "Fermeture forcée de %@ demandée manuellement."
        ],
        "systemProcesses.title": [
            .en: "System Processes",
            .zhHans: "系统进程",
            .zhHant: "系統行程",
            .ja: "システムプロセス",
            .de: "Systemprozesse",
            .fr: "Processus système"
        ],
        "systemProcesses.subtitle": [
            .en: "%d processes outside any app · %@ in total · right-click to force quit; root processes ask for an administrator password",
            .zhHans: "%d 个不属于任何 App 的进程 · 合计 %@ · 右键可强制退出，root 进程需要管理员密码",
            .zhHant: "%d 個不屬於任何 App 的行程 · 合計 %@ · 按右鍵可強制結束，root 行程需要管理員密碼",
            .ja: "どのアプリにも属さないプロセス %d 個 · 合計 %@ · 右クリックで強制終了（root プロセスは管理者パスワードが必要）",
            .de: "%d Prozesse außerhalb von Apps · insgesamt %@ · Rechtsklick zum sofortigen Beenden; root-Prozesse erfordern ein Administratorpasswort",
            .fr: "%d processus hors app · %@ au total · clic droit pour forcer à quitter ; les processus root demandent un mot de passe administrateur"
        ],
        "systemProcesses.cardHint": [
            .en: "%d background processes outside any app · %@ in total · measured like Activity Monitor",
            .zhHans: "%d 个不属于任何 App 的后台进程 · 合计 %@ · 与活动监视器同口径",
            .zhHant: "%d 個不屬於任何 App 的背景行程 · 合計 %@ · 與活動監視器同口徑",
            .ja: "どのアプリにも属さないバックグラウンドプロセス %d 個 · 合計 %@ · アクティビティモニタと同じ基準",
            .de: "%d Hintergrundprozesse außerhalb von Apps · insgesamt %@ · gemessen wie in der Aktivitätsanzeige",
            .fr: "%d processus d’arrière-plan hors app · %@ au total · mesuré comme le Moniteur d’activité"
        ],
        "systemProcesses.search": [
            .en: "Search processes or PID",
            .zhHans: "搜索进程名或 PID",
            .zhHant: "搜尋行程名稱或 PID",
            .ja: "プロセス名または PID を検索",
            .de: "Prozess oder PID suchen",
            .fr: "Rechercher un processus ou un PID"
        ],
        "systemProcesses.showAll": [
            .en: "Show All",
            .zhHans: "查看全部",
            .zhHant: "查看全部",
            .ja: "すべて表示",
            .de: "Alle anzeigen",
            .fr: "Tout afficher"
        ],
        "systemProcesses.loading": [
            .en: "Reading process memory…",
            .zhHans: "正在读取进程内存…",
            .zhHant: "正在讀取行程記憶體…",
            .ja: "プロセスのメモリを読み取り中…",
            .de: "Prozessspeicher wird gelesen …",
            .fr: "Lecture de la mémoire des processus…"
        ],
        "systemProcesses.protected": [
            .en: "Critical system process, can’t be quit",
            .zhHans: "关键系统进程，不能结束",
            .zhHant: "關鍵系統行程，無法結束",
            .ja: "重要なシステムプロセスのため終了できません",
            .de: "Kritischer Systemprozess, kann nicht beendet werden",
            .fr: "Processus système critique, impossible de le quitter"
        ],
        "systemProcesses.forceQuitAdmin": [
            .en: "Force Quit %@ (Administrator)…",
            .zhHans: "强制退出 %@（需要管理员密码）…",
            .zhHant: "強制結束 %@（需要管理員密碼）…",
            .ja: "%@ を強制終了（管理者パスワードが必要）…",
            .de: "%@ sofort beenden (Administrator) …",
            .fr: "Forcer %@ à quitter (administrateur)…"
        ],
        "systemProcesses.currentUser": [
            .en: "current user",
            .zhHans: "当前用户",
            .zhHant: "目前使用者",
            .ja: "現在のユーザ",
            .de: "aktueller Benutzer",
            .fr: "utilisateur actuel"
        ],
        "systemProcesses.forceQuitConfirmMessage": [
            .en: "The process ends immediately. If it’s a system service, macOS restarts it when needed.",
            .zhHans: "进程会立即结束。如果它是系统服务，macOS 会在需要时重新启动它。",
            .zhHant: "行程會立即結束。如果它是系統服務，macOS 會在需要時重新啟動它。",
            .ja: "プロセスはすぐに終了します。システムサービスの場合は、必要に応じて macOS が再起動します。",
            .de: "Der Prozess wird sofort beendet. Systemdienste startet macOS bei Bedarf neu.",
            .fr: "Le processus s’arrête immédiatement. S’il s’agit d’un service système, macOS le relance au besoin."
        ],
        "systemProcesses.suspectedLeak": [
            .en: "Suspected Leak",
            .zhHans: "疑似泄漏",
            .zhHant: "疑似洩漏",
            .ja: "リークの疑い",
            .de: "Mögliches Leck",
            .fr: "Fuite suspectée"
        ],
        "systemProcesses.adminPrompt": [
            .en: "GreenRAM wants to end system process %@, which looks like it is leaking memory (%@).",
            .zhHans: "GreenRAM 要结束疑似内存泄漏的系统进程 %@（占用 %@）。",
            .zhHant: "GreenRAM 要結束疑似記憶體洩漏的系統行程 %@（佔用 %@）。",
            .ja: "GreenRAM は、メモリリークの疑いがあるシステムプロセス %@（%@ 使用中）を終了しようとしています。",
            .de: "GreenRAM möchte den Systemprozess %@ beenden, der vermutlich Speicher verliert (%@).",
            .fr: "GreenRAM veut arrêter le processus système %@, qui semble perdre de la mémoire (%@)."
        ],
        "event.systemMemoryLeakTerminating": [
            .en: "%@ (PID %d) looks like it is leaking memory: %@, up %@ within an hour. Ending it automatically.",
            .zhHans: "%@（PID %d）疑似内存泄漏：%@，1 小时内增长 %@，自动结束。",
            .zhHant: "%@（PID %d）疑似記憶體洩漏：%@，1 小時內增長 %@，自動結束。",
            .ja: "%@（PID %d）にメモリリークの疑い：%@、1 時間で %@ 増加。自動的に終了します。",
            .de: "%@ (PID %d) verliert vermutlich Speicher: %@, %@ mehr innerhalb einer Stunde. Wird automatisch beendet.",
            .fr: "%@ (PID %d) semble perdre de la mémoire : %@, +%@ en une heure. Arrêt automatique."
        ],
        "event.systemMemoryLeakFlagged": [
            .en: "%@ (PID %d) looks like it is leaking memory: %@, up %@ within an hour. Not a system process, so it was left running; right-click it in System Processes to quit it.",
            .zhHans: "%@（PID %d）疑似内存泄漏：%@，1 小时内增长 %@。不是系统进程，未自动结束，可在系统进程页右键结束。",
            .zhHant: "%@（PID %d）疑似記憶體洩漏：%@，1 小時內增長 %@。不是系統行程，未自動結束，可在系統行程頁按右鍵結束。",
            .ja: "%@（PID %d）にメモリリークの疑い：%@、1 時間で %@ 増加。システムプロセスではないため自動終了していません。システムプロセスページで右クリックして終了できます。",
            .de: "%@ (PID %d) verliert vermutlich Speicher: %@, %@ mehr innerhalb einer Stunde. Kein Systemprozess, daher nicht beendet; per Rechtsklick unter Systemprozesse beenden.",
            .fr: "%@ (PID %d) semble perdre de la mémoire : %@, +%@ en une heure. Ce n’est pas un processus système, il n’a pas été arrêté ; clic droit dans Processus système pour le quitter."
        ],
        "event.systemProcessTerminateCancelled": [
            .en: "Cancelled ending system process %@.",
            .zhHans: "已取消结束系统进程 %@。",
            .zhHant: "已取消結束系統行程 %@。",
            .ja: "システムプロセス %@ の終了をキャンセルしました。",
            .de: "Beenden von Systemprozess %@ abgebrochen.",
            .fr: "Arrêt du processus système %@ annulé."
        ],
        "event.systemProcessTerminated": [
            .en: "Ended system process %@.",
            .zhHans: "已结束系统进程 %@。",
            .zhHant: "已結束系統行程 %@。",
            .ja: "システムプロセス %@ を終了しました。",
            .de: "Systemprozess %@ beendet.",
            .fr: "Processus système %@ arrêté."
        ],
        "event.systemProcessTerminateFailed": [
            .en: "Failed to end system process %@: %@",
            .zhHans: "结束系统进程 %@ 失败：%@",
            .zhHant: "結束系統行程 %@ 失敗：%@",
            .ja: "システムプロセス %@ の終了に失敗しました：%@",
            .de: "Beenden von Systemprozess %@ fehlgeschlagen: %@",
            .fr: "Échec de l’arrêt du processus système %@ : %@"
        ]
    ]
}
