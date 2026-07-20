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
            .en: "Quit Eligible Apps Now",
            .zhHans: "立即退出符合规则的 App",
            .zhHant: "立即結束符合規則的 App",
            .ja: "対象アプリを今すぐ終了",
            .de: "Geeignete Apps jetzt beenden",
            .fr: "Quitter les apps admissibles"
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
            .zhHans: "%d 个自动退出 App · %d 个超时时间 · %d 个内存上限 · %d 个保护项",
            .zhHant: "%d 個自動退出 App · %d 個逾時時間 · %d 個記憶體上限 · %d 個保護項",
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
            .zhHans: "自动退出 App",
            .zhHant: "自動退出 App",
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
            .zhHans: "没有自动退出 App",
            .zhHant: "沒有自動退出 App",
            .ja: "自動終了アプリはありません",
            .de: "Keine Apps zum automatischen Beenden",
            .fr: "Aucune app en auto-fermeture"
        ],
        "settings.removeAutoQuitApp": [
            .en: "Remove %@ from Auto-Quit Apps",
            .zhHans: "从自动退出 App 中移除 %@",
            .zhHant: "從自動退出 App 中移除 %@",
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
            .zhHans: "这会恢复清理限制，并移除自动退出 App、单 App 超时时间和单 App 内存上限。语言设置不会改变。",
            .zhHant: "這會恢復清理限制，並移除自動退出 App、單 App 逾時時間和單 App 記憶體上限。語言設定不會改變。",
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
        ]
    ]
}
