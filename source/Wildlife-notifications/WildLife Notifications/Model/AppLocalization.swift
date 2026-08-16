import Foundation

enum AppLanguage: Int, CaseIterable, Identifiable, Equatable {
    case english = 0
    case spanish
    case french
    case italian
    case chinese
    case japanese
    case korean
    case german

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        case .french: "French"
        case .italian: "Italian"
        case .chinese: "Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .german: "German"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english: "en"
        case .spanish: "es"
        case .french: "fr"
        case .italian: "it"
        case .chinese: "zh-Hans"
        case .japanese: "ja"
        case .korean: "ko"
        case .german: "de"
        }
    }

    var languageCodes: [String] {
        switch self {
        case .english: ["en"]
        case .spanish: ["es"]
        case .french: ["fr"]
        case .italian: ["it"]
        case .chinese: ["zh"]
        case .japanese: ["ja"]
        case .korean: ["ko"]
        case .german: ["de"]
        }
    }

    static func language(for index: Int) -> AppLanguage {
        AppLanguage(rawValue: index) ?? .english
    }
}

enum AppTextKey: String, CaseIterable {
    case accept
    case addNewCamera
    case alertPinnedTitle
    case apiKey
    case appDescription
    case archiveImmich
    case authorized
    case body
    case cancel
    case cameraName
    case cameraType
    case cameraLocation
    case cameraDelete
    case cameraDeleteQuestion
    case cameraSaveFailed
    case cameras
    case camerasToBot
    case checkNotificationStatus
    case changePhoto
    case confirmUseLanguage
    case continueAction
    case customActions
    case databaseDelete
    case dateDelete
    case delete
    case deleteDateTitle
    case deleteImmichTitle
    case deleteToTrash
    case denied
    case detectedLanguageMessage
    case enableNotifications
    case ephemeral
    case ftpPassword
    case ftpPort
    case ftpProtocol
    case ftpSettings
    case ftpSettingsFooter
    case ftpUpload
    case ftpUser
    case general
    case getPlotted
    case githubLink
    case hostIP
    case imageLoading
    case imageLoadingFailed
    case immichApiKey
    case immichId
    case immichUrl
    case language
    case no
    case noCameras
    case noImageAvailable
    case noPhoto
    case notificationStatus
    case notificationStatusLine
    case notifications
    case notificationFooterDisabled
    case notDetermined
    case pinnedWarningMessage
    case pin
    case unpin
    case provisional
    case explicit
    case performNetworkRequest
    case refreshView
    case requestPermission
    case save
    case selectPhoto
    case scrollHint
    case scrollHintAccessibility
    case scrollPosition
    case settings
    case sharePhoto
    case subtitle
    case testLocalPush
    case title
    case topOfList
    case unknown
    case unpinnedDelete
    case update
    case updateAll
    case useLanguageButton
    case incomingPaymentsNotifications
    case whatIsWildsichtung
    case whatDoINeed
    case wildlifeSettings
    case wildSightings
    case yes
}

func appText(_ key: AppTextKey, languageIndex: Int) -> String {
    let language = AppLanguage.language(for: languageIndex)
    return appTexts[language]?[key] ?? englishAppTexts[key] ?? key.rawValue
}

private let appTexts: [AppLanguage: [AppTextKey: String]] = [
    .english: englishAppTexts,
    .spanish: spanishAppTexts,
    .french: frenchAppTexts,
    .italian: italianAppTexts,
    .chinese: chineseAppTexts,
    .japanese: japaneseAppTexts,
    .korean: koreanAppTexts,
    .german: germanAppTexts,
]

private let englishAppTexts: [AppTextKey: String] = [
    .accept: "Accept",
    .addNewCamera: "Add new camera",
    .alertPinnedTitle: "Pinned notifications",
    .apiKey: "API key",
    .appDescription: "WildLife Notifications helps you improve wildlife management by monitoring and observing wildlife.",
    .archiveImmich: "Immich archive",
    .authorized: "Authorized",
    .body: "Body:",
    .cancel: "Cancel",
    .cameraName: "Camera name",
    .cameraType: "Camera type",
    .cameraLocation: "Camera location",
    .cameraDelete: "Delete camera",
    .cameraDeleteQuestion: "Delete camera?",
    .cameraSaveFailed: "Camera could not be saved",
    .cameras: "Cameras",
    .camerasToBot: "Send cameras to JagdBildBot",
    .checkNotificationStatus: "Check notification status",
    .changePhoto: "Change photo",
    .confirmUseLanguage: "Use language?",
    .continueAction: "Continue",
    .customActions: "Custom actions:",
    .databaseDelete: "Delete database",
    .dateDelete: "Delete date...",
    .delete: "Delete",
    .deleteDateTitle: "Delete photos",
    .deleteImmichTitle: "Delete Immich photos",
    .deleteToTrash: "Move to trash",
    .denied: "Denied",
    .detectedLanguageMessage: "Your device uses %@. Do you want to use this language in WildLife Notifications as well?",
    .enableNotifications: "Enable notifications",
    .ephemeral: "Ephemeral",
    .ftpPassword: "FTP password",
    .ftpPort: "FTP port",
    .ftpProtocol: "Protocol",
    .ftpSettings: "FTP settings",
    .ftpSettingsFooter: "Optional connection to an FTP server: %@",
    .ftpUpload: "FTP upload",
    .ftpUser: "FTP user",
    .general: "General",
    .getPlotted: "Get plotted",
    .githubLink: "View WildLife Notifications on GitHub",
    .hostIP: "Host / IP",
    .imageLoading: "Loading image...",
    .imageLoadingFailed: "Image loading failed",
    .immichApiKey: "Immich API key",
    .immichId: "Immich ID:",
    .immichUrl: "Immich URL",
    .language: "Language",
    .no: "No",
    .noCameras: "No cameras available",
    .noImageAvailable: "No image available",
    .noPhoto: "No photo available",
    .notificationStatus: "Notification status",
    .notificationStatusLine: "WildLife Notifications status:",
    .notifications: "Notifications",
    .notificationFooterDisabled: "Turn on to see more settings.",
    .notDetermined: "Not decided",
    .pinnedWarningMessage: "Some notifications are pinned. If you delete the database, they will be lost. Do you really want to delete the database?",
    .pin: "Pin",
    .unpin: "Unpin",
    .provisional: "Provisional",
    .explicit: "Explicit",
    .performNetworkRequest: "Perform network request",
    .refreshView: "Refresh view",
    .requestPermission: "Request permission",
    .save: "Save",
    .selectPhoto: "Select photo",
    .scrollHint: "Fast scroll on the right edge",
    .scrollHintAccessibility: "Hint: fast scroll on the right edge",
    .scrollPosition: "List position",
    .settings: "Settings",
    .sharePhoto: "Share photo",
    .subtitle: "Subtitle:",
    .testLocalPush: "Test local push",
    .title: "Title:",
    .topOfList: "Top of list",
    .unknown: "Unknown",
    .unpinnedDelete: "Delete unpinned",
    .update: "Update",
    .updateAll: "Update all",
    .useLanguageButton: "Yes, use %@",
    .incomingPaymentsNotifications: "Enable incoming payments notifications",
    .whatIsWildsichtung: "What is WildLife Notifications?",
    .whatDoINeed: "What do I need for WildLife Notifications?",
    .wildlifeSettings: "WildLife Notifications settings",
    .wildSightings: "Wildlife sightings",
    .yes: "Yes",
]

private let spanishAppTexts: [AppTextKey: String] = [
    .accept: "Aceptar",
    .addNewCamera: "Añadir cámara nueva",
    .alertPinnedTitle: "Notificaciones fijadas",
    .apiKey: "Clave API",
    .appDescription: "WildLife Notifications te ayuda a mejorar la gestión de fauna mediante el seguimiento y la observación de animales silvestres.",
    .archiveImmich: "Archivo de Immich",
    .authorized: "Autorizado",
    .body: "Texto:",
    .cancel: "Cancelar",
    .cameraName: "Nombre de la cámara",
    .cameraType: "Tipo de cámara",
    .cameraLocation: "Ubicación de la cámara",
    .cameraDelete: "Eliminar cámara",
    .cameraDeleteQuestion: "¿Eliminar cámara?",
    .cameraSaveFailed: "No se pudo guardar la cámara",
    .cameras: "Cámaras",
    .camerasToBot: "Enviar cámaras a JagdBildBot",
    .checkNotificationStatus: "Comprobar estado de notificaciones",
    .changePhoto: "Cambiar foto",
    .confirmUseLanguage: "¿Usar idioma?",
    .continueAction: "Continuar",
    .customActions: "Acciones personalizadas:",
    .databaseDelete: "Eliminar base de datos",
    .dateDelete: "Eliminar fecha...",
    .delete: "Eliminar",
    .deleteDateTitle: "Eliminar fotos",
    .deleteImmichTitle: "Eliminar fotos de Immich",
    .deleteToTrash: "Mover a la papelera",
    .denied: "Denegado",
    .detectedLanguageMessage: "Tu dispositivo usa %@. ¿Quieres usar este idioma también en WildLife Notifications?",
    .enableNotifications: "Activar notificaciones",
    .ephemeral: "Efímero",
    .ftpPassword: "Contraseña FTP",
    .ftpPort: "Puerto FTP",
    .ftpProtocol: "Protocolo",
    .ftpSettings: "Ajustes FTP",
    .ftpSettingsFooter: "Conexión opcional a un servidor FTP: %@",
    .ftpUpload: "Carga FTP",
    .ftpUser: "Usuario FTP",
    .general: "General",
    .getPlotted: "Solicitar trazado",
    .githubLink: "Ver WildLife Notifications en GitHub",
    .hostIP: "Host / IP",
    .imageLoading: "Cargando imagen...",
    .imageLoadingFailed: "No se pudo cargar la imagen",
    .immichApiKey: "Clave API de Immich",
    .immichId: "ID de Immich:",
    .immichUrl: "URL de Immich",
    .language: "Idioma",
    .no: "No",
    .noCameras: "No hay cámaras disponibles",
    .noImageAvailable: "No hay imagen disponible",
    .noPhoto: "No hay foto disponible",
    .notificationStatus: "Estado de notificaciones",
    .notificationStatusLine: "Estado de WildLife Notifications:",
    .notifications: "Notificaciones",
    .notificationFooterDisabled: "Activa esta opción para ver más ajustes.",
    .notDetermined: "No decidido",
    .pinnedWarningMessage: "Algunas notificaciones están fijadas. Si eliminas la base de datos, se perderán. ¿Realmente quieres eliminar la base de datos?",
    .pin: "Fijar",
    .unpin: "Desfijar",
    .provisional: "Provisional",
    .explicit: "Explícito",
    .performNetworkRequest: "Realizar solicitud de red",
    .refreshView: "Actualizar vista",
    .requestPermission: "Solicitar permiso",
    .save: "Guardar",
    .selectPhoto: "Seleccionar foto",
    .scrollHint: "Desplazamiento rápido en el borde derecho",
    .scrollHintAccessibility: "Consejo: desplazamiento rápido en el borde derecho",
    .scrollPosition: "Posición en la lista",
    .settings: "Ajustes",
    .sharePhoto: "Compartir foto",
    .subtitle: "Subtítulo:",
    .testLocalPush: "Probar push local",
    .title: "Título:",
    .topOfList: "Inicio de la lista",
    .unknown: "Desconocido",
    .unpinnedDelete: "Eliminar no fijadas",
    .update: "Actualizar",
    .updateAll: "Actualizar todo",
    .useLanguageButton: "Sí, usar %@",
    .incomingPaymentsNotifications: "Activar notificaciones de pagos entrantes",
    .whatIsWildsichtung: "¿Qué es WildLife Notifications?",
    .whatDoINeed: "¿Qué necesito para WildLife Notifications?",
    .wildlifeSettings: "Ajustes de WildLife Notifications",
    .wildSightings: "Avistamientos de fauna",
    .yes: "Sí",
]

private let frenchAppTexts: [AppTextKey: String] = [
    .accept: "Accepter",
    .addNewCamera: "Ajouter une caméra",
    .alertPinnedTitle: "Notifications épinglées",
    .apiKey: "Clé API",
    .appDescription: "WildLife Notifications vous aide à améliorer la gestion de la faune en surveillant et en observant les animaux sauvages.",
    .archiveImmich: "Archive Immich",
    .authorized: "Autorisé",
    .body: "Texte :",
    .cancel: "Annuler",
    .cameraName: "Nom de la caméra",
    .cameraType: "Type de caméra",
    .cameraLocation: "Emplacement de la caméra",
    .cameraDelete: "Supprimer la caméra",
    .cameraDeleteQuestion: "Supprimer la caméra ?",
    .cameraSaveFailed: "La caméra n’a pas pu être enregistrée",
    .cameras: "Caméras",
    .camerasToBot: "Envoyer les caméras à JagdBildBot",
    .checkNotificationStatus: "Vérifier l’état des notifications",
    .changePhoto: "Changer la photo",
    .confirmUseLanguage: "Utiliser la langue ?",
    .continueAction: "Continuer",
    .customActions: "Actions personnalisées :",
    .databaseDelete: "Supprimer la base de données",
    .dateDelete: "Supprimer une date...",
    .delete: "Supprimer",
    .deleteDateTitle: "Supprimer les photos",
    .deleteImmichTitle: "Supprimer les photos Immich",
    .deleteToTrash: "Mettre à la corbeille",
    .denied: "Refusé",
    .detectedLanguageMessage: "Votre appareil utilise %@. Voulez-vous aussi utiliser cette langue dans WildLife Notifications ?",
    .enableNotifications: "Activer les notifications",
    .ephemeral: "Éphémère",
    .ftpPassword: "Mot de passe FTP",
    .ftpPort: "Port FTP",
    .ftpProtocol: "Protocole",
    .ftpSettings: "Paramètres FTP",
    .ftpSettingsFooter: "Connexion facultative à un serveur FTP : %@",
    .ftpUpload: "Téléversement FTP",
    .ftpUser: "Utilisateur FTP",
    .general: "Général",
    .getPlotted: "Demander le tracé",
    .githubLink: "Voir WildLife Notifications sur GitHub",
    .hostIP: "Hôte / IP",
    .imageLoading: "Chargement de l’image...",
    .imageLoadingFailed: "Le chargement de l’image a échoué",
    .immichApiKey: "Clé API Immich",
    .immichId: "ID Immich :",
    .immichUrl: "URL Immich",
    .language: "Langue",
    .no: "Non",
    .noCameras: "Aucune caméra disponible",
    .noImageAvailable: "Aucune image disponible",
    .noPhoto: "Aucune photo disponible",
    .notificationStatus: "État des notifications",
    .notificationStatusLine: "État de WildLife Notifications :",
    .notifications: "Notifications",
    .notificationFooterDisabled: "Activez cette option pour voir plus de paramètres.",
    .notDetermined: "Non décidé",
    .pinnedWarningMessage: "Certaines notifications sont épinglées. Si vous supprimez la base de données, elles seront perdues. Voulez-vous vraiment supprimer la base de données ?",
    .pin: "Épingler",
    .unpin: "Désépingler",
    .provisional: "Provisoire",
    .explicit: "Explicite",
    .performNetworkRequest: "Effectuer une requête réseau",
    .refreshView: "Actualiser la vue",
    .requestPermission: "Demander l’autorisation",
    .save: "Enregistrer",
    .selectPhoto: "Sélectionner une photo",
    .scrollHint: "Défilement rapide sur le bord droit",
    .scrollHintAccessibility: "Astuce : défilement rapide sur le bord droit",
    .scrollPosition: "Position dans la liste",
    .settings: "Réglages",
    .sharePhoto: "Partager la photo",
    .subtitle: "Sous-titre :",
    .testLocalPush: "Tester une notification locale",
    .title: "Titre :",
    .topOfList: "Début de la liste",
    .unknown: "Inconnu",
    .unpinnedDelete: "Supprimer les non épinglées",
    .update: "Mettre à jour",
    .updateAll: "Tout mettre à jour",
    .useLanguageButton: "Oui, utiliser %@",
    .incomingPaymentsNotifications: "Activer les notifications de paiements entrants",
    .whatIsWildsichtung: "Qu’est-ce que WildLife Notifications ?",
    .whatDoINeed: "De quoi ai-je besoin pour WildLife Notifications ?",
    .wildlifeSettings: "Réglages de WildLife Notifications",
    .wildSightings: "Observations de faune",
    .yes: "Oui",
]

private let italianAppTexts: [AppTextKey: String] = [
    .accept: "Accetta",
    .addNewCamera: "Aggiungi nuova fotocamera",
    .alertPinnedTitle: "Notifiche fissate",
    .apiKey: "Chiave API",
    .appDescription: "WildLife Notifications ti aiuta a migliorare la gestione della fauna monitorando e osservando gli animali selvatici.",
    .archiveImmich: "Archivio Immich",
    .authorized: "Autorizzato",
    .body: "Testo:",
    .cancel: "Annulla",
    .cameraName: "Nome fotocamera",
    .cameraType: "Tipo fotocamera",
    .cameraLocation: "Posizione fotocamera",
    .cameraDelete: "Elimina fotocamera",
    .cameraDeleteQuestion: "Eliminare la fotocamera?",
    .cameraSaveFailed: "Impossibile salvare la fotocamera",
    .cameras: "Fotocamere",
    .camerasToBot: "Invia fotocamere a JagdBildBot",
    .checkNotificationStatus: "Controlla stato notifiche",
    .changePhoto: "Cambia foto",
    .confirmUseLanguage: "Usare la lingua?",
    .continueAction: "Continua",
    .customActions: "Azioni personalizzate:",
    .databaseDelete: "Elimina database",
    .dateDelete: "Elimina data...",
    .delete: "Elimina",
    .deleteDateTitle: "Elimina foto",
    .deleteImmichTitle: "Elimina foto Immich",
    .deleteToTrash: "Sposta nel cestino",
    .denied: "Negato",
    .detectedLanguageMessage: "Il tuo dispositivo usa %@. Vuoi usare questa lingua anche in WildLife Notifications?",
    .enableNotifications: "Attiva notifiche",
    .ephemeral: "Effimero",
    .ftpPassword: "Password FTP",
    .ftpPort: "Porta FTP",
    .ftpProtocol: "Protocollo",
    .ftpSettings: "Impostazioni FTP",
    .ftpSettingsFooter: "Connessione opzionale a un server FTP: %@",
    .ftpUpload: "Caricamento FTP",
    .ftpUser: "Utente FTP",
    .general: "Generale",
    .getPlotted: "Richiedi tracciamento",
    .githubLink: "Vedi WildLife Notifications su GitHub",
    .hostIP: "Host / IP",
    .imageLoading: "Caricamento immagine...",
    .imageLoadingFailed: "Caricamento immagine non riuscito",
    .immichApiKey: "Chiave API Immich",
    .immichId: "ID Immich:",
    .immichUrl: "URL Immich",
    .language: "Lingua",
    .no: "No",
    .noCameras: "Nessuna fotocamera disponibile",
    .noImageAvailable: "Nessuna immagine disponibile",
    .noPhoto: "Nessuna foto disponibile",
    .notificationStatus: "Stato notifiche",
    .notificationStatusLine: "Stato di WildLife Notifications:",
    .notifications: "Notifiche",
    .notificationFooterDisabled: "Attiva per vedere altre impostazioni.",
    .notDetermined: "Non deciso",
    .pinnedWarningMessage: "Alcune notifiche sono fissate. Se elimini il database, andranno perse. Vuoi davvero eliminare il database?",
    .pin: "Fissa",
    .unpin: "Rimuovi fissaggio",
    .provisional: "Provvisorio",
    .explicit: "Esplicito",
    .performNetworkRequest: "Esegui richiesta di rete",
    .refreshView: "Aggiorna vista",
    .requestPermission: "Richiedi permesso",
    .save: "Salva",
    .selectPhoto: "Seleziona foto",
    .scrollHint: "Scorrimento rapido sul bordo destro",
    .scrollHintAccessibility: "Suggerimento: scorrimento rapido sul bordo destro",
    .scrollPosition: "Posizione nella lista",
    .settings: "Impostazioni",
    .sharePhoto: "Condividi foto",
    .subtitle: "Sottotitolo:",
    .testLocalPush: "Prova push locale",
    .title: "Titolo:",
    .topOfList: "Inizio lista",
    .unknown: "Sconosciuto",
    .unpinnedDelete: "Elimina non fissate",
    .update: "Aggiorna",
    .updateAll: "Aggiorna tutto",
    .useLanguageButton: "Sì, usa %@",
    .incomingPaymentsNotifications: "Attiva notifiche per pagamenti in arrivo",
    .whatIsWildsichtung: "Che cos’è WildLife Notifications?",
    .whatDoINeed: "Cosa serve per WildLife Notifications?",
    .wildlifeSettings: "Impostazioni WildLife Notifications",
    .wildSightings: "Avvistamenti di fauna",
    .yes: "Sì",
]

private let chineseAppTexts: [AppTextKey: String] = [
    .accept: "接受",
    .addNewCamera: "添加新相机",
    .alertPinnedTitle: "已固定的通知",
    .apiKey: "API 密钥",
    .appDescription: "WildLife Notifications 可帮助你通过监测和观察野生动物来改进野生动物管理。",
    .archiveImmich: "Immich 归档",
    .authorized: "已授权",
    .body: "正文：",
    .cancel: "取消",
    .cameraName: "相机名称",
    .cameraType: "相机类型",
    .cameraLocation: "相机位置",
    .cameraDelete: "删除相机",
    .cameraDeleteQuestion: "删除相机？",
    .cameraSaveFailed: "无法保存相机",
    .cameras: "相机",
    .camerasToBot: "将相机发送到 JagdBildBot",
    .checkNotificationStatus: "检查通知状态",
    .changePhoto: "更换照片",
    .confirmUseLanguage: "使用该语言？",
    .continueAction: "继续",
    .customActions: "自定义操作：",
    .databaseDelete: "删除数据库",
    .dateDelete: "删除日期...",
    .delete: "删除",
    .deleteDateTitle: "删除照片",
    .deleteImmichTitle: "删除 Immich 照片",
    .deleteToTrash: "移到回收站",
    .denied: "已拒绝",
    .detectedLanguageMessage: "你的设备使用 %@。是否也在 WildLife Notifications 中使用该语言？",
    .enableNotifications: "启用通知",
    .ephemeral: "临时",
    .ftpPassword: "FTP 密码",
    .ftpPort: "FTP 端口",
    .ftpProtocol: "协议",
    .ftpSettings: "FTP 设置",
    .ftpSettingsFooter: "可选连接到 FTP 服务器：%@",
    .ftpUpload: "FTP 上传",
    .ftpUser: "FTP 用户",
    .general: "常规",
    .getPlotted: "请求绘图",
    .githubLink: "在 GitHub 上查看 WildLife Notifications",
    .hostIP: "主机 / IP",
    .imageLoading: "正在加载图像...",
    .imageLoadingFailed: "图像加载失败",
    .immichApiKey: "Immich API 密钥",
    .immichId: "Immich ID：",
    .immichUrl: "Immich URL",
    .language: "语言",
    .no: "否",
    .noCameras: "没有可用相机",
    .noImageAvailable: "没有可用图像",
    .noPhoto: "没有可用照片",
    .notificationStatus: "通知状态",
    .notificationStatusLine: "WildLife Notifications 状态：",
    .notifications: "通知",
    .notificationFooterDisabled: "开启后可查看更多设置。",
    .notDetermined: "未决定",
    .pinnedWarningMessage: "有些通知已固定。如果删除数据库，它们将会丢失。确定要删除数据库吗？",
    .pin: "固定",
    .unpin: "取消固定",
    .provisional: "临时授权",
    .explicit: "明确",
    .performNetworkRequest: "执行网络请求",
    .refreshView: "刷新视图",
    .requestPermission: "请求权限",
    .save: "保存",
    .selectPhoto: "选择照片",
    .scrollHint: "在右边缘快速滚动",
    .scrollHintAccessibility: "提示：在右边缘快速滚动",
    .scrollPosition: "列表位置",
    .settings: "设置",
    .sharePhoto: "分享照片",
    .subtitle: "副标题：",
    .testLocalPush: "测试本地推送",
    .title: "标题：",
    .topOfList: "列表顶部",
    .unknown: "未知",
    .unpinnedDelete: "删除未固定项",
    .update: "更新",
    .updateAll: "全部更新",
    .useLanguageButton: "是，使用 %@",
    .incomingPaymentsNotifications: "启用收款通知",
    .whatIsWildsichtung: "什么是 WildLife Notifications？",
    .whatDoINeed: "使用 WildLife Notifications 需要什么？",
    .wildlifeSettings: "WildLife Notifications 设置",
    .wildSightings: "野生动物目击",
    .yes: "是",
]

private let japaneseAppTexts: [AppTextKey: String] = [
    .accept: "承認",
    .addNewCamera: "新しいカメラを追加",
    .alertPinnedTitle: "ピン留めされた通知",
    .apiKey: "APIキー",
    .appDescription: "WildLife Notifications は、野生動物の監視と観察を通じて野生動物管理を改善するのに役立ちます。",
    .archiveImmich: "Immich アーカイブ",
    .authorized: "許可済み",
    .body: "本文:",
    .cancel: "キャンセル",
    .cameraName: "カメラ名",
    .cameraType: "カメラの種類",
    .cameraLocation: "カメラの場所",
    .cameraDelete: "カメラを削除",
    .cameraDeleteQuestion: "カメラを削除しますか？",
    .cameraSaveFailed: "カメラを保存できませんでした",
    .cameras: "カメラ",
    .camerasToBot: "カメラを JagdBildBot に送信",
    .checkNotificationStatus: "通知状態を確認",
    .changePhoto: "写真を変更",
    .confirmUseLanguage: "言語を使用しますか？",
    .continueAction: "続ける",
    .customActions: "カスタム操作:",
    .databaseDelete: "データベースを削除",
    .dateDelete: "日付を削除...",
    .delete: "削除",
    .deleteDateTitle: "写真を削除",
    .deleteImmichTitle: "Immich 写真を削除",
    .deleteToTrash: "ゴミ箱へ移動",
    .denied: "拒否",
    .detectedLanguageMessage: "このデバイスでは %@ が使用されています。WildLife Notifications でもこの言語を使用しますか？",
    .enableNotifications: "通知を有効化",
    .ephemeral: "一時的",
    .ftpPassword: "FTP パスワード",
    .ftpPort: "FTP ポート",
    .ftpProtocol: "プロトコル",
    .ftpSettings: "FTP 設定",
    .ftpSettingsFooter: "FTP サーバーへの任意接続: %@",
    .ftpUpload: "FTP アップロード",
    .ftpUser: "FTP ユーザー",
    .general: "一般",
    .getPlotted: "プロットを要求",
    .githubLink: "GitHub で WildLife Notifications を表示",
    .hostIP: "ホスト / IP",
    .imageLoading: "画像を読み込み中...",
    .imageLoadingFailed: "画像の読み込みに失敗しました",
    .immichApiKey: "Immich APIキー",
    .immichId: "Immich ID:",
    .immichUrl: "Immich URL",
    .language: "言語",
    .no: "いいえ",
    .noCameras: "利用可能なカメラがありません",
    .noImageAvailable: "利用可能な画像がありません",
    .noPhoto: "利用可能な写真がありません",
    .notificationStatus: "通知状態",
    .notificationStatusLine: "WildLife Notifications の状態:",
    .notifications: "通知",
    .notificationFooterDisabled: "オンにすると詳細設定が表示されます。",
    .notDetermined: "未決定",
    .pinnedWarningMessage: "ピン留めされた通知があります。データベースを削除すると失われます。本当にデータベースを削除しますか？",
    .pin: "ピン留め",
    .unpin: "ピン留め解除",
    .provisional: "暫定",
    .explicit: "明示的",
    .performNetworkRequest: "ネットワークリクエストを実行",
    .refreshView: "表示を更新",
    .requestPermission: "権限を要求",
    .save: "保存",
    .selectPhoto: "写真を選択",
    .scrollHint: "右端で高速スクロール",
    .scrollHintAccessibility: "ヒント: 右端で高速スクロール",
    .scrollPosition: "リスト位置",
    .settings: "設定",
    .sharePhoto: "写真を共有",
    .subtitle: "サブタイトル:",
    .testLocalPush: "ローカルプッシュをテスト",
    .title: "タイトル:",
    .topOfList: "リストの先頭",
    .unknown: "不明",
    .unpinnedDelete: "ピン留めされていない項目を削除",
    .update: "更新",
    .updateAll: "すべて更新",
    .useLanguageButton: "はい、%@ を使用",
    .incomingPaymentsNotifications: "入金通知を有効化",
    .whatIsWildsichtung: "WildLife Notifications とは？",
    .whatDoINeed: "WildLife Notifications に必要なものは？",
    .wildlifeSettings: "WildLife Notifications 設定",
    .wildSightings: "野生動物の目撃",
    .yes: "はい",
]

private let koreanAppTexts: [AppTextKey: String] = [
    .accept: "승인",
    .addNewCamera: "새 카메라 추가",
    .alertPinnedTitle: "고정된 알림",
    .apiKey: "API 키",
    .appDescription: "WildLife Notifications는 야생동물의 모니터링과 관찰을 통해 야생동물 관리를 개선하도록 도와줍니다.",
    .archiveImmich: "Immich 보관함",
    .authorized: "허용됨",
    .body: "본문:",
    .cancel: "취소",
    .cameraName: "카메라 이름",
    .cameraType: "카메라 유형",
    .cameraLocation: "카메라 위치",
    .cameraDelete: "카메라 삭제",
    .cameraDeleteQuestion: "카메라를 삭제할까요?",
    .cameraSaveFailed: "카메라를 저장할 수 없습니다",
    .cameras: "카메라",
    .camerasToBot: "카메라를 JagdBildBot으로 보내기",
    .checkNotificationStatus: "알림 상태 확인",
    .changePhoto: "사진 변경",
    .confirmUseLanguage: "언어를 사용할까요?",
    .continueAction: "계속",
    .customActions: "사용자 지정 동작:",
    .databaseDelete: "데이터베이스 삭제",
    .dateDelete: "날짜 삭제...",
    .delete: "삭제",
    .deleteDateTitle: "사진 삭제",
    .deleteImmichTitle: "Immich 사진 삭제",
    .deleteToTrash: "휴지통으로 이동",
    .denied: "거부됨",
    .detectedLanguageMessage: "기기에서 %@ 언어를 사용 중입니다. WildLife Notifications에서도 이 언어를 사용할까요?",
    .enableNotifications: "알림 활성화",
    .ephemeral: "일시적",
    .ftpPassword: "FTP 비밀번호",
    .ftpPort: "FTP 포트",
    .ftpProtocol: "프로토콜",
    .ftpSettings: "FTP 설정",
    .ftpSettingsFooter: "FTP 서버에 선택적으로 연결: %@",
    .ftpUpload: "FTP 업로드",
    .ftpUser: "FTP 사용자",
    .general: "일반",
    .getPlotted: "플롯 요청",
    .githubLink: "GitHub에서 WildLife Notifications 보기",
    .hostIP: "호스트 / IP",
    .imageLoading: "이미지 로드 중...",
    .imageLoadingFailed: "이미지를 불러오지 못했습니다",
    .immichApiKey: "Immich API 키",
    .immichId: "Immich ID:",
    .immichUrl: "Immich URL",
    .language: "언어",
    .no: "아니요",
    .noCameras: "사용 가능한 카메라가 없습니다",
    .noImageAvailable: "사용 가능한 이미지가 없습니다",
    .noPhoto: "사용 가능한 사진이 없습니다",
    .notificationStatus: "알림 상태",
    .notificationStatusLine: "WildLife Notifications 상태:",
    .notifications: "알림",
    .notificationFooterDisabled: "켜면 더 많은 설정을 볼 수 있습니다.",
    .notDetermined: "결정되지 않음",
    .pinnedWarningMessage: "고정된 알림이 있습니다. 데이터베이스를 삭제하면 해당 알림이 사라집니다. 정말 데이터베이스를 삭제할까요?",
    .pin: "고정",
    .unpin: "고정 해제",
    .provisional: "임시",
    .explicit: "명시적",
    .performNetworkRequest: "네트워크 요청 실행",
    .refreshView: "보기 새로고침",
    .requestPermission: "권한 요청",
    .save: "저장",
    .selectPhoto: "사진 선택",
    .scrollHint: "오른쪽 가장자리에서 빠르게 스크롤",
    .scrollHintAccessibility: "힌트: 오른쪽 가장자리에서 빠르게 스크롤",
    .scrollPosition: "목록 위치",
    .settings: "설정",
    .sharePhoto: "사진 공유",
    .subtitle: "부제목:",
    .testLocalPush: "로컬 푸시 테스트",
    .title: "제목:",
    .topOfList: "목록 맨 위",
    .unknown: "알 수 없음",
    .unpinnedDelete: "고정되지 않은 항목 삭제",
    .update: "업데이트",
    .updateAll: "모두 업데이트",
    .useLanguageButton: "예, %@ 사용",
    .incomingPaymentsNotifications: "수신 결제 알림 활성화",
    .whatIsWildsichtung: "WildLife Notifications란?",
    .whatDoINeed: "WildLife Notifications에 필요한 것은?",
    .wildlifeSettings: "WildLife Notifications 설정",
    .wildSightings: "야생동물 목격",
    .yes: "예",
]

private let germanAppTexts: [AppTextKey: String] = [
    .accept: "Akzeptieren",
    .addNewCamera: "Neue Kamera hinzufügen",
    .alertPinnedTitle: "Angeheftete Meldungen",
    .apiKey: "API-Schlüssel",
    .appDescription: "WildLife Notifications hilft dir, das Wildmanagement zu verbessern und Wildtiere zu beobachten.",
    .archiveImmich: "Immich-Archiv",
    .authorized: "Autorisiert",
    .body: "Text:",
    .cancel: "Abbrechen",
    .cameraName: "Kameraname",
    .cameraType: "Kameratyp",
    .cameraLocation: "Kamerastandort",
    .cameraDelete: "Kamera löschen",
    .cameraDeleteQuestion: "Kamera löschen?",
    .cameraSaveFailed: "Kamera konnte nicht gespeichert werden",
    .cameras: "Kameras",
    .camerasToBot: "Kameras an den JagdBildBot senden",
    .checkNotificationStatus: "Benachrichtigungsstatus prüfen",
    .changePhoto: "Foto ändern",
    .confirmUseLanguage: "Sprache übernehmen?",
    .continueAction: "Weiter",
    .customActions: "Eigene Aktionen:",
    .databaseDelete: "Datenbank löschen",
    .dateDelete: "Datum löschen...",
    .delete: "Löschen",
    .deleteDateTitle: "Bilder löschen",
    .deleteImmichTitle: "Immich-Bilder löschen",
    .deleteToTrash: "In Papierkorb",
    .denied: "Verweigert",
    .detectedLanguageMessage: "Dein Gerät verwendet %@. Möchtest du diese Sprache auch in WildLife Notifications nutzen?",
    .enableNotifications: "Benachrichtigungen aktivieren",
    .ephemeral: "Kurzzeitig",
    .ftpPassword: "FTP-Passwort",
    .ftpPort: "FTP-Port",
    .ftpProtocol: "Protokoll",
    .ftpSettings: "FTP-Einstellungen",
    .ftpSettingsFooter: "Optionale Anbindung an einen FTP-Server: %@",
    .ftpUpload: "FTP-Upload",
    .ftpUser: "FTP-Benutzer",
    .general: "Allgemein",
    .getPlotted: "Plot anfordern",
    .githubLink: "WildLife Notifications auf GitHub ansehen",
    .hostIP: "Host / IP",
    .imageLoading: "Foto wird geladen",
    .imageLoadingFailed: "Bild konnte nicht geladen werden",
    .immichApiKey: "Immich API-Schlüssel",
    .immichId: "Immich-ID:",
    .immichUrl: "Immich-URL",
    .language: "Sprache",
    .no: "Nein",
    .noCameras: "Keine Kameras vorhanden",
    .noImageAvailable: "Kein Bild vorhanden",
    .noPhoto: "Kein Foto vorhanden",
    .notificationStatus: "Benachrichtigungsstatus",
    .notificationStatusLine: "WildLife Notifications Status:",
    .notifications: "Benachrichtigungen",
    .notificationFooterDisabled: "Aktivieren, um weitere Einstellungen zu sehen.",
    .notDetermined: "Nicht entschieden",
    .pinnedWarningMessage: "Es gibt angeheftete Meldungen. Wenn du die Datenbank löschst, gehen diese verloren. Möchtest du die Datenbank wirklich löschen?",
    .pin: "Anheften",
    .unpin: "Lösen",
    .provisional: "Vorläufig",
    .explicit: "Explizit",
    .performNetworkRequest: "Netzwerkanfrage ausführen",
    .refreshView: "Ansicht aktualisieren",
    .requestPermission: "Berechtigung anfordern",
    .save: "Speichern",
    .selectPhoto: "Foto auswählen",
    .scrollHint: "Am rechten Rand schnell scrollen",
    .scrollHintAccessibility: "Hinweis: Am rechten Rand schnell scrollen",
    .scrollPosition: "Listenposition",
    .settings: "Einstellungen",
    .sharePhoto: "Foto teilen",
    .subtitle: "Untertitel:",
    .testLocalPush: "Lokale Push-Nachricht testen",
    .title: "Titel:",
    .topOfList: "Zum Anfang",
    .unknown: "Unbekannt",
    .unpinnedDelete: "Nicht angeheftete löschen",
    .update: "Aktualisieren",
    .updateAll: "Alle aktualisieren",
    .useLanguageButton: "Ja, %@ nutzen",
    .incomingPaymentsNotifications: "Benachrichtigungen für eingehende Zahlungen aktivieren",
    .whatIsWildsichtung: "Was ist WildLife Notifications?",
    .whatDoINeed: "Was benötige ich für WildLife Notifications?",
    .wildlifeSettings: "WildLife Notifications Einstellungen",
    .wildSightings: "Wildsichtungen",
    .yes: "Ja",
]
