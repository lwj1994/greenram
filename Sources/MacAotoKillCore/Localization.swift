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
        "risk.low": [
            .en: "Low Risk",
            .zhHans: "低风险",
            .zhHant: "低風險",
            .ja: "低リスク",
            .de: "Niedriges Risiko",
            .fr: "Risque faible"
        ],
        "risk.medium": [
            .en: "Medium Risk",
            .zhHans: "中风险",
            .zhHant: "中風險",
            .ja: "中リスク",
            .de: "Mittleres Risiko",
            .fr: "Risque moyen"
        ],
        "risk.high": [
            .en: "High Risk",
            .zhHans: "高风险",
            .zhHant: "高風險",
            .ja: "高リスク",
            .de: "Hohes Risiko",
            .fr: "Risque élevé"
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
        "menu.compressed": [
            .en: "Compressed",
            .zhHans: "压缩内存",
            .zhHant: "壓縮記憶體",
            .ja: "圧縮メモリ",
            .de: "Komprimiert",
            .fr: "Compressée"
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
            .en: "Auto Quit When Over Limit",
            .zhHans: "超限自动结束后台 App",
            .zhHant: "超限自動結束背景 App",
            .ja: "上限超過時に背景アプリを終了",
            .de: "Bei Limitüberschreitung automatisch beenden",
            .fr: "Fermer automatiquement au dépassement"
        ],
        "menu.aggressiveForceKill": [
            .en: "Aggressive Force Kill",
            .zhHans: "激进强杀",
            .zhHant: "激進強制結束",
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
        "menu.releaseNow": [
            .en: "Quit Background Apps Now",
            .zhHans: "立即结束后台 App",
            .zhHant: "立即結束背景 App",
            .ja: "背景アプリを今すぐ終了",
            .de: "Hintergrund-Apps jetzt beenden",
            .fr: "Fermer les apps en arrière-plan"
        ],
        "menu.quit": [
            .en: "Quit",
            .zhHans: "退出",
            .zhHant: "結束",
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
            .en: "No eligible background apps",
            .zhHans: "没有可结束的后台 App",
            .zhHant: "沒有可結束的背景 App",
            .ja: "終了できる背景アプリはありません",
            .de: "Keine geeigneten Hintergrund-Apps",
            .fr: "Aucune app admissible en arrière-plan"
        ],
        "menu.releaseCandidates": [
            .en: "Background Apps GreenRAM May Quit",
            .zhHans: "可结束的后台 App",
            .zhHant: "可結束的背景 App",
            .ja: "GreenRAMが終了できる背景アプリ",
            .de: "Beendbare Hintergrund-Apps",
            .fr: "Apps en arrière-plan pouvant être fermées"
        ],
        "menu.childProcessCount": [
            .en: "%d child processes",
            .zhHans: "%d 个子进程",
            .zhHant: "%d 個子行程",
            .ja: "子プロセス %d 個",
            .de: "%d Kindprozesse",
            .fr: "%d processus enfants"
        ],
        "menu.protected": [
            .en: "Protected",
            .zhHans: "已保护",
            .zhHant: "已保護",
            .ja: "保護済み",
            .de: "Geschützt",
            .fr: "Protégée"
        ],
        "menu.noBackgroundApps": [
            .en: "No background regular apps",
            .zhHans: "没有后台普通应用",
            .zhHant: "沒有背景普通 App",
            .ja: "バックグラウンドアプリなし",
            .de: "Keine normalen Hintergrund-Apps",
            .fr: "Aucune app standard en arrière-plan"
        ],
        "menu.backgroundApps": [
            .en: "Background Apps",
            .zhHans: "后台应用",
            .zhHant: "背景 App",
            .ja: "バックグラウンドアプリ",
            .de: "Hintergrund-Apps",
            .fr: "Apps en arrière-plan"
        ],
        "menu.noWhitelistItems": [
            .en: "No custom whitelist items",
            .zhHans: "没有自定义白名单",
            .zhHant: "沒有自訂白名單",
            .ja: "カスタム項目なし",
            .de: "Keine eigenen Whitelist-Einträge",
            .fr: "Aucune entrée personnalisée"
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
            .zhHans: "已用物理内存",
            .zhHant: "已用實體記憶體",
            .ja: "使用中のRAM",
            .de: "Verwendeter RAM",
            .fr: "RAM utilisée"
        ],
        "settings.swapUsed": [
            .en: "Swap Used",
            .zhHans: "已用交换内存",
            .zhHant: "已用交換記憶體",
            .ja: "使用中のスワップ",
            .de: "Verwendete Auslagerung",
            .fr: "Swap utilisé"
        ],
        "settings.releaseThresholds": [
            .en: "Trigger Limits",
            .zhHans: "触发上限",
            .zhHant: "觸發上限",
            .ja: "実行上限",
            .de: "Auslöselimits",
            .fr: "Limites de déclenchement"
        ],
        "settings.autoReleaseCheckbox": [
            .en: "Auto quit background apps when over limit",
            .zhHans: "超限后自动结束后台 App",
            .zhHant: "超限後自動結束背景 App",
            .ja: "上限超過時に背景アプリを自動終了",
            .de: "Hintergrund-Apps bei Limitüberschreitung beenden",
            .fr: "Fermer les apps en arrière-plan au dépassement"
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
            .zhHans: "Swap 最大值",
            .zhHant: "Swap 最大值",
            .ja: "Swap上限",
            .de: "Swap-Maximum",
            .fr: "Swap max"
        ],
        "settings.swapLimitEnabled": [
            .en: "Use Swap limit",
            .zhHans: "启用 Swap 阈值",
            .zhHant: "啟用 Swap 閾值",
            .ja: "Swap上限を使う",
            .de: "Swap-Limit verwenden",
            .fr: "Utiliser la limite Swap"
        ],
        "settings.swapMinimumHint": [
            .en: "Default is half of physical RAM. Minimum is 2 GB. Turn this off to ignore Swap.",
            .zhHans: "默认是物理内存的一半；最低 2GB。关闭开关即可忽略 Swap。",
            .zhHant: "預設是實體記憶體的一半；最低 2GB。關閉開關即可忽略 Swap。",
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
        "settings.minimumAppMemory": [
            .en: "Minimum app memory",
            .zhHans: "可结束 App 最小内存",
            .zhHant: "可結束 App 最小記憶體",
            .ja: "候補アプリの最小メモリ",
            .de: "Min. App-Speicher",
            .fr: "Mémoire app minimale"
        ],
        "settings.warningIdleTime": [
            .en: "Warning idle time",
            .zhHans: "警告闲置时长",
            .zhHant: "警告閒置時間",
            .ja: "警告時の待機時間",
            .de: "Leerlaufzeit bei Warnung",
            .fr: "Inactivité en alerte"
        ],
        "settings.criticalIdleTime": [
            .en: "Critical idle time",
            .zhHans: "严重闲置时长",
            .zhHant: "嚴重閒置時間",
            .ja: "危険時の待機時間",
            .de: "Leerlaufzeit kritisch",
            .fr: "Inactivité critique"
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
            .en: "Reset memory policy settings?",
            .zhHans: "恢复内存策略默认值？",
            .zhHant: "恢復記憶體策略預設值？",
            .ja: "メモリポリシー設定を既定値に戻しますか？",
            .de: "Speicherrichtlinie zurücksetzen?",
            .fr: "Réinitialiser la politique mémoire ?"
        ],
        "settings.resetConfirmMessage": [
            .en: "This restores RAM Max and Swap settings. Language will stay unchanged.",
            .zhHans: "这会恢复 RAM 最大值和 Swap 设置。语言设置不会改变。",
            .zhHant: "這會恢復 RAM 最大值和 Swap 設定。語言設定不會改變。",
            .ja: "RAM上限とSwap設定を既定値に戻します。言語設定は変更されません。",
            .de: "RAM-Maximum und Swap-Einstellungen werden zurückgesetzt. Die Sprache bleibt unverändert.",
            .fr: "RAM max et réglages Swap seront réinitialisés. La langue restera inchangée."
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
        "event.memoryPressureChanged": [
            .en: "Memory pressure changed to %@.",
            .zhHans: "内存压力变为 %@。",
            .zhHant: "記憶體壓力變為 %@。",
            .ja: "メモリ圧力が %@ になりました。",
            .de: "Speicherdruck geändert zu %@.",
            .fr: "Pression mémoire passée à %@."
        ],
        "event.autoReleaseTrigger": [
            .en: "Auto quit trigger: %@.",
            .zhHans: "自动结束触发：%@。",
            .zhHant: "自動結束觸發：%@。",
            .ja: "自動終了トリガー：%@。",
            .de: "Automatisches Beenden ausgelöst: %@.",
            .fr: "Déclenchement de fermeture : %@."
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
            .en: "Auto quit enabled.",
            .zhHans: "超限自动结束已开启。",
            .zhHant: "超限自動結束已開啟。",
            .ja: "自動終了を有効にしました。",
            .de: "Automatisches Beenden aktiviert.",
            .fr: "Fermeture automatique activée."
        ],
        "event.autoReleaseDisabled": [
            .en: "Auto quit disabled.",
            .zhHans: "超限自动结束已关闭。",
            .zhHant: "超限自動結束已關閉。",
            .ja: "自動終了を無効にしました。",
            .de: "Automatisches Beenden deaktiviert.",
            .fr: "Fermeture automatique désactivée."
        ],
        "event.aggressiveEnabled": [
            .en: "Aggressive force kill enabled.",
            .zhHans: "激进强杀已开启。",
            .zhHant: "激進強制結束已開啟。",
            .ja: "強制終了モードを有効にしました。",
            .de: "Aggressives Beenden aktiviert.",
            .fr: "Fermeture forcée activée."
        ],
        "event.aggressiveDisabled": [
            .en: "Aggressive force kill disabled.",
            .zhHans: "激进强杀已关闭。",
            .zhHant: "激進強制結束已關閉。",
            .ja: "強制終了モードを無効にしました。",
            .de: "Aggressives Beenden deaktiviert.",
            .fr: "Fermeture forcée désactivée."
        ],
        "event.manualRelease": [
            .en: "Manual background app quit requested.",
            .zhHans: "已手动结束后台 App。",
            .zhHant: "已手動結束背景 App。",
            .ja: "背景アプリの手動終了を要求しました。",
            .de: "Manuelles Beenden von Hintergrund-Apps angefordert.",
            .fr: "Fermeture manuelle des apps en arrière-plan demandée."
        ],
        "event.settingsUpdated": [
            .en: "Memory policy settings updated.",
            .zhHans: "内存策略设置已更新。",
            .zhHant: "記憶體策略設定已更新。",
            .ja: "メモリポリシー設定を更新しました。",
            .de: "Speicherrichtlinien aktualisiert.",
            .fr: "Réglages de politique mémoire mis à jour."
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
            .en: "Auto quit is disabled; pressure event ignored.",
            .zhHans: "超限自动结束已关闭；忽略压力事件。",
            .zhHant: "超限自動結束已關閉；忽略壓力事件。",
            .ja: "自動終了が無効なため圧力イベントを無視しました。",
            .de: "Automatisches Beenden deaktiviert; Druckereignis ignoriert.",
            .fr: "Fermeture automatique désactivée ; événement ignoré."
        ],
        "event.noEligibleApps": [
            .en: "No eligible background apps.",
            .zhHans: "没有符合条件的后台应用。",
            .zhHant: "沒有符合條件的背景 App。",
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
            .zhHant: "已請求結束 %@（%@）。",
            .ja: "%@ の終了を要求しました（%@）。",
            .de: "Beenden von %@ angefordert (%@).",
            .fr: "Fermeture demandée pour %@ (%@)."
        ],
        "event.quitFailed": [
            .en: "Quit request failed for %@.",
            .zhHans: "请求退出 %@ 失败。",
            .zhHant: "請求結束 %@ 失敗。",
            .ja: "%@ の終了要求に失敗しました。",
            .de: "Beenden von %@ fehlgeschlagen.",
            .fr: "Échec de fermeture pour %@."
        ],
        "event.forceTerminated": [
            .en: "Force terminated %@.",
            .zhHans: "已强制结束 %@。",
            .zhHant: "已強制結束 %@。",
            .ja: "%@ を強制終了しました。",
            .de: "%@ wurde erzwungen beendet.",
            .fr: "%@ a été forcée à quitter."
        ],
        "event.forceTerminateFailed": [
            .en: "Force terminate failed for %@.",
            .zhHans: "强制结束 %@ 失败。",
            .zhHant: "強制結束 %@ 失敗。",
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
