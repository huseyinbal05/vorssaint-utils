// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct VideoDownloaderStrings {
    let pageTitle: String
    let hubDescription: String
    let panelCaption: String
    let urlPlaceholder: String
    let urlHelp: String
    let paste: String
    let inspecting: String
    let video: String
    let mp3: String
    let quality: String
    let best: String
    let heightFormat: String
    let qualityFallbackFormat: String
    let subtitles: String
    let none: String
    let manual: String
    let automatic: String
    let destination: String
    let choose: String
    let showInPanel: String
    let settingsCaption: String
    let defaultLocation: String
    let resetDownloads: String
    let embedThumbnail: String
    let embedMetadata: String
    let embedChapters: String
    let embedSubtitle: String
    let lyrics: String
    let dependencies: String
    let missingToolsFormat: String
    let installMissingTools: String
    let setUpDownloader: String
    let brewSetupNote: String
    let terminalSetupNote: String
    let checkingTools: String
    let downloadVideo: String
    let downloadMP3: String
    let downloading: String
    let percentFormat: String
    let speedFormat: String
    let etaFormat: String
    let finalizing: String
    let cancel: String
    let cancelling: String
    let complete: String
    let downloadAnother: String
    let revealFinder: String
    let retry: String
    let cancelled: String
    let failureTitle: String
    let uploader: String
    let duration: String
    let thumbnail: String
    let errorURLInvalid: String
    let errorURLTooLong: String
    let errorURLControl: String
    let errorURLCredentials: String
    let errorInspectionTimeout: String
    let errorInspectionFailed: String
    let errorInspectionTooLarge: String
    let errorInspectionMalformed: String
    let errorPlaylist: String
    let errorLive: String
    let errorDRM: String
    let errorRestricted: String
    let errorNoFormats: String
    let errorNoVideo: String
    let errorNoAudio: String
    let errorMissingDependencies: String
    let errorSetupBusy: String
    let errorSetupFailed: String
    let errorTerminalPermission: String
    let errorDownloadFailed: String
    let errorRemux: String
    let errorSubtitle: String
    let errorOptionalData: String
    let errorLyrics: String
    let errorFileSafety: String

    var allValues: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }

    var requiredErrors: [String] {
        [errorURLInvalid, errorURLTooLong, errorURLControl, errorURLCredentials,
         errorInspectionTimeout, errorInspectionFailed, errorInspectionTooLarge,
         errorInspectionMalformed, errorPlaylist, errorLive, errorDRM, errorRestricted,
         errorNoFormats, errorNoVideo, errorNoAudio, errorMissingDependencies,
         errorSetupBusy, errorSetupFailed, errorTerminalPermission, errorDownloadFailed,
         errorRemux, errorSubtitle, errorOptionalData, errorLyrics, errorFileSafety]
    }

    func message(for error: VideoURLValidationError) -> String {
        switch error {
        case .tooLong: return errorURLTooLong
        case .controlCharacter: return errorURLControl
        case .credentials: return errorURLCredentials
        case .empty, .unsupportedScheme, .missingHost, .malformed: return errorURLInvalid
        }
    }

    func message(for error: VideoDownloaderFailure) -> String {
        switch error {
        case let .invalidURL(validation): return message(for: validation)
        case .inspectionTimedOut: return errorInspectionTimeout
        case .inspectionFailed: return errorInspectionFailed
        case .inspectionTooLarge: return errorInspectionTooLarge
        case .malformedInspection: return errorInspectionMalformed
        case .playlist: return errorPlaylist
        case .live: return errorLive
        case .drm: return errorDRM
        case .restricted: return errorRestricted
        case .noFormats: return errorNoFormats
        case .noVideo: return errorNoVideo
        case .noAudio: return errorNoAudio
        case .missingDependencies: return errorMissingDependencies
        case .setupBusy: return errorSetupBusy
        case .setupFailed: return errorSetupFailed
        case .terminalPermission: return errorTerminalPermission
        case .downloadFailed: return errorDownloadFailed
        case .mp4Remux: return errorRemux
        case .subtitle: return errorSubtitle
        case .optionalData: return errorOptionalData
        case .lyrics: return errorLyrics
        case .fileSafety: return errorFileSafety
        case .cancelled: return cancelled
        }
    }
}

extension FeatureStrings {
    static func videoDownloader(_ language: AppLanguage) -> VideoDownloaderStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension VideoDownloaderStrings {
    static let enUS = VideoDownloaderStrings(
        pageTitle: "Video Downloader",
        hubDescription: "Download one public video or MP3 with quality and subtitle choices",
        panelCaption: "Save one public media link as MP4 or MP3",
        urlPlaceholder: "Paste a public HTTP or HTTPS media URL",
        urlHelp: "The URL is inspected only after it is valid. It is not saved or put in process arguments.",
        paste: "Paste",
        inspecting: "Inspecting media…",
        video: "Video",
        mp3: "MP3",
        quality: "Video quality",
        best: "Best",
        heightFormat: "%dp",
        qualityFallbackFormat: "%dp was unavailable; %dp was selected instead.",
        subtitles: "Subtitles",
        none: "None",
        manual: "Manual",
        automatic: "Automatic",
        destination: "Download folder",
        choose: "Choose…",
        showInPanel: "Show in menu panel",
        settingsCaption: "Downloads are staged privately and only the finished MP4 or MP3 is placed in your folder.",
        defaultLocation: "Default download location",
        resetDownloads: "Reset to Downloads",
        embedThumbnail: "Embed thumbnail in MP4 / cover art in MP3",
        embedMetadata: "Embed metadata",
        embedChapters: "Embed chapters in MP4",
        embedSubtitle: "Embed the selected subtitle in MP4",
        lyrics: "Add the selected subtitle text as MP3 lyrics",
        dependencies: "Downloader tools",
        missingToolsFormat: "Missing: %@",
        installMissingTools: "Install missing tools",
        setUpDownloader: "Set up downloader",
        brewSetupNote: "Homebrew installs only the missing yt-dlp and ffmpeg tools. You can cancel while it runs.",
        terminalSetupNote: "Terminal will open for the official Homebrew setup and may ask for confirmation or your password, then installs yt-dlp and ffmpeg.",
        checkingTools: "Checking downloader tools…",
        downloadVideo: "Download Video",
        downloadMP3: "Download MP3",
        downloading: "Downloading",
        percentFormat: "%.0f%%",
        speedFormat: "%@/s",
        etaFormat: "ETA %@",
        finalizing: "Finalizing…",
        cancel: "Cancel",
        cancelling: "Cancelling…",
        complete: "Download complete",
        downloadAnother: "Download Another",
        revealFinder: "Reveal in Finder",
        retry: "Retry",
        cancelled: "Download cancelled",
        failureTitle: "Could not finish the download",
        uploader: "Uploader",
        duration: "Duration",
        thumbnail: "Media thumbnail",
        errorURLInvalid: "Enter a complete public HTTP or HTTPS media URL.",
        errorURLTooLong: "This URL is too long to inspect safely.",
        errorURLControl: "The URL contains a line break or control character.",
        errorURLCredentials: "URLs containing a username or password are not supported.",
        errorInspectionTimeout: "Inspection took too long. Check the link and try again.",
        errorInspectionFailed: "The media could not be inspected. Make sure it is public and available.",
        errorInspectionTooLarge: "The site returned more media information than can be handled safely.",
        errorInspectionMalformed: "The media information returned by yt-dlp was not usable.",
        errorPlaylist: "Playlists, channels and collections are not supported. Paste one media item.",
        errorLive: "Live and upcoming streams are not supported.",
        errorDRM: "DRM-protected media cannot be downloaded.",
        errorRestricted: "Private, paid or sign-in restricted media is not supported.",
        errorNoFormats: "No usable media formats were found for this link.",
        errorNoVideo: "This item has no usable video stream. Choose MP3 instead.",
        errorNoAudio: "This item has no usable audio stream.",
        errorMissingDependencies: "yt-dlp and ffmpeg are both required to download.",
        errorSetupBusy: "Another Homebrew operation is already running. Try again when it finishes.",
        errorSetupFailed: "The downloader tools could not be installed. Check Homebrew and try again.",
        errorTerminalPermission: "Terminal could not be opened. Allow Terminal Automation in System Settings and try again.",
        errorDownloadFailed: "The media download failed. Check that the link is still public and available.",
        errorRemux: "The selected streams cannot be merged or remuxed to MP4 without transcoding. Choose another quality.",
        errorSubtitle: "The selected subtitle could not be downloaded and embedded. No incomplete file was published.",
        errorOptionalData: "The requested artwork, metadata or chapters could not be embedded. No incomplete file was published.",
        errorLyrics: "The selected captions could not be added as MP3 lyrics. No incomplete file was published.",
        errorFileSafety: "The finished file could not be verified or safely placed in the selected folder."
    )

    static let ptBR = VideoDownloaderStrings(
        pageTitle: "Baixador de vídeos", hubDescription: "Baixe um vídeo público ou MP3 com opções de qualidade e legenda",
        panelCaption: "Salve um link público como MP4 ou MP3",
        urlPlaceholder: "Cole uma URL pública HTTP ou HTTPS", urlHelp: "A URL só é analisada quando é válida. Ela não é salva nem colocada nos argumentos do processo.",
        paste: "Colar", inspecting: "Analisando mídia…", video: "Vídeo", mp3: "MP3", quality: "Qualidade do vídeo", best: "Melhor",
        heightFormat: "%dp", qualityFallbackFormat: "%dp não estava disponível; %dp foi selecionado.",
        subtitles: "Legendas", none: "Nenhuma", manual: "Manual", automatic: "Automática",
        destination: "Pasta de download", choose: "Escolher…", showInPanel: "Mostrar no painel do menu",
        settingsCaption: "Os downloads ficam numa área temporária privada e só o MP4 ou MP3 final vai para sua pasta.",
        defaultLocation: "Local padrão dos downloads", resetDownloads: "Redefinir para Downloads",
        embedThumbnail: "Incorporar miniatura no MP4 / capa no MP3", embedMetadata: "Incorporar metadados",
        embedChapters: "Incorporar capítulos no MP4", embedSubtitle: "Incorporar a legenda selecionada no MP4",
        lyrics: "Adicionar o texto da legenda selecionada como letra no MP3", dependencies: "Ferramentas do baixador",
        missingToolsFormat: "Faltando: %@", installMissingTools: "Instalar ferramentas ausentes", setUpDownloader: "Configurar baixador",
        brewSetupNote: "O Homebrew instala apenas yt-dlp e ffmpeg que estiverem faltando. Você pode cancelar durante a execução.",
        terminalSetupNote: "O Terminal abrirá a configuração oficial do Homebrew e poderá pedir confirmação ou senha; depois instalará yt-dlp e ffmpeg.",
        checkingTools: "Verificando ferramentas…", downloadVideo: "Baixar vídeo", downloadMP3: "Baixar MP3", downloading: "Baixando",
        percentFormat: "%.0f%%", speedFormat: "%@/s", etaFormat: "Tempo restante %@", finalizing: "Finalizando…", cancel: "Cancelar",
        cancelling: "Cancelando…", complete: "Download concluído", downloadAnother: "Baixar outro", revealFinder: "Mostrar no Finder",
        retry: "Tentar novamente", cancelled: "Download cancelado", failureTitle: "Não foi possível concluir o download",
        uploader: "Publicador", duration: "Duração", thumbnail: "Miniatura da mídia",
        errorURLInvalid: "Digite uma URL pública HTTP ou HTTPS completa.", errorURLTooLong: "Esta URL é longa demais para uma análise segura.",
        errorURLControl: "A URL contém quebra de linha ou caractere de controle.", errorURLCredentials: "URLs com nome de usuário ou senha não são aceitas.",
        errorInspectionTimeout: "A análise demorou demais. Verifique o link e tente novamente.",
        errorInspectionFailed: "Não foi possível analisar a mídia. Confirme que ela é pública e está disponível.",
        errorInspectionTooLarge: "O site retornou mais informações de mídia do que é seguro processar.",
        errorInspectionMalformed: "As informações retornadas pelo yt-dlp não puderam ser usadas.",
        errorPlaylist: "Playlists, canais e coleções não são aceitos. Cole um único item.", errorLive: "Transmissões ao vivo ou futuras não são aceitas.",
        errorDRM: "Mídia protegida por DRM não pode ser baixada.", errorRestricted: "Mídia privada, paga ou restrita por login não é aceita.",
        errorNoFormats: "Nenhum formato de mídia utilizável foi encontrado.", errorNoVideo: "Este item não tem vídeo utilizável. Escolha MP3.",
        errorNoAudio: "Este item não tem áudio utilizável.", errorMissingDependencies: "yt-dlp e ffmpeg são necessários para baixar.",
        errorSetupBusy: "Outra operação do Homebrew está em andamento. Tente depois que terminar.",
        errorSetupFailed: "Não foi possível instalar as ferramentas. Verifique o Homebrew e tente novamente.",
        errorTerminalPermission: "Não foi possível abrir o Terminal. Permita Automação do Terminal nos Ajustes do Sistema.",
        errorDownloadFailed: "O download falhou. Confirme que o link continua público e disponível.",
        errorRemux: "Os fluxos selecionados não podem ser unidos ou remultiplexados em MP4 sem transcodificação. Escolha outra qualidade.",
        errorSubtitle: "Não foi possível baixar e incorporar a legenda selecionada. Nenhum arquivo incompleto foi publicado.",
        errorOptionalData: "Não foi possível incorporar a capa, os metadados ou os capítulos solicitados. Nenhum arquivo incompleto foi publicado.",
        errorLyrics: "Não foi possível adicionar as legendas como letra do MP3. Nenhum arquivo incompleto foi publicado.",
        errorFileSafety: "Não foi possível verificar ou colocar com segurança o arquivo final na pasta selecionada."
    )

    static let tr = VideoDownloaderStrings(
        pageTitle: "Video İndirici", hubDescription: "Herkese açık tek bir videoyu kalite ve altyazı seçimiyle video veya MP3 olarak indir",
        panelCaption: "Herkese açık bir medya bağlantısını MP4 veya MP3 olarak kaydet",
        urlPlaceholder: "Herkese açık bir HTTP veya HTTPS medya URL’si yapıştırın", urlHelp: "URL yalnızca geçerliyse incelenir; kaydedilmez ve işlem argümanlarına konmaz.",
        paste: "Yapıştır", inspecting: "Medya inceleniyor…", video: "Video", mp3: "MP3", quality: "Video kalitesi", best: "En iyi",
        heightFormat: "%dp", qualityFallbackFormat: "%dp kullanılamıyordu; yerine %dp seçildi.",
        subtitles: "Altyazılar", none: "Yok", manual: "Elle hazırlanmış", automatic: "Otomatik",
        destination: "İndirme klasörü", choose: "Seç…", showInPanel: "Menü panelinde göster",
        settingsCaption: "İndirme özel bir geçici alanda hazırlanır; klasörünüze yalnızca bitmiş MP4 veya MP3 konur.",
        defaultLocation: "Varsayılan indirme konumu", resetDownloads: "İndirilenler’e sıfırla",
        embedThumbnail: "MP4’e küçük resim / MP3’e kapak ekle", embedMetadata: "Üst veriyi ekle", embedChapters: "Bölümleri MP4’e ekle",
        embedSubtitle: "Seçili altyazıyı MP4’e ekle", lyrics: "Seçili altyazı metnini MP3 sözleri olarak ekle",
        dependencies: "İndirme araçları", missingToolsFormat: "Eksik: %@", installMissingTools: "Eksik araçları yükle", setUpDownloader: "İndiriciyi kur",
        brewSetupNote: "Homebrew yalnızca eksik yt-dlp ve ffmpeg araçlarını yükler. Çalışırken iptal edebilirsiniz.",
        terminalSetupNote: "Resmî Homebrew kurulumu Terminal’de açılır; onay veya parolanızı isteyebilir, ardından yt-dlp ve ffmpeg’i yükler.",
        checkingTools: "İndirme araçları denetleniyor…", downloadVideo: "Videoyu indir", downloadMP3: "MP3 indir", downloading: "İndiriliyor",
        percentFormat: "%%%.0f", speedFormat: "%@/sn", etaFormat: "Kalan %@", finalizing: "Tamamlanıyor…", cancel: "İptal",
        cancelling: "İptal ediliyor…", complete: "İndirme tamamlandı", downloadAnother: "Başka indir", revealFinder: "Finder’da göster",
        retry: "Yeniden dene", cancelled: "İndirme iptal edildi", failureTitle: "İndirme tamamlanamadı", uploader: "Yükleyen",
        duration: "Süre", thumbnail: "Medya küçük resmi",
        errorURLInvalid: "Tam bir herkese açık HTTP veya HTTPS medya URL’si girin.", errorURLTooLong: "Bu URL güvenle incelenemeyecek kadar uzun.",
        errorURLControl: "URL satır sonu veya denetim karakteri içeriyor.", errorURLCredentials: "Kullanıcı adı veya parola içeren URL’ler desteklenmez.",
        errorInspectionTimeout: "İnceleme çok uzun sürdü. Bağlantıyı denetleyip yeniden deneyin.",
        errorInspectionFailed: "Medya incelenemedi. Herkese açık ve erişilebilir olduğundan emin olun.",
        errorInspectionTooLarge: "Site güvenle işlenebilecek miktardan fazla medya bilgisi döndürdü.",
        errorInspectionMalformed: "yt-dlp’nin döndürdüğü medya bilgisi kullanılamadı.",
        errorPlaylist: "Oynatma listeleri, kanallar ve koleksiyonlar desteklenmez. Tek bir medya öğesi yapıştırın.",
        errorLive: "Canlı ve yaklaşan yayınlar desteklenmez.", errorDRM: "DRM korumalı medya indirilemez.",
        errorRestricted: "Özel, ücretli veya oturum açma kısıtlı medya desteklenmez.", errorNoFormats: "Kullanılabilir medya biçimi bulunamadı.",
        errorNoVideo: "Bu öğede kullanılabilir video akışı yok. MP3’ü seçin.", errorNoAudio: "Bu öğede kullanılabilir ses akışı yok.",
        errorMissingDependencies: "İndirmek için yt-dlp ve ffmpeg gereklidir.", errorSetupBusy: "Başka bir Homebrew işlemi sürüyor. Bittiğinde yeniden deneyin.",
        errorSetupFailed: "İndirme araçları yüklenemedi. Homebrew’i denetleyip yeniden deneyin.",
        errorTerminalPermission: "Terminal açılamadı. Sistem Ayarları’nda Terminal Otomasyonu’na izin verip yeniden deneyin.",
        errorDownloadFailed: "Medya indirilemedi. Bağlantının hâlâ herkese açık ve erişilebilir olduğunu denetleyin.",
        errorRemux: "Seçili akışlar kod dönüştürmeden MP4’e birleştirilemiyor. Başka bir kalite seçin.",
        errorSubtitle: "Seçili altyazı indirilemedi ve eklenemedi. Eksik dosya yayımlanmadı.",
        errorOptionalData: "İstenen kapak görseli, üst veri veya bölümler eklenemedi. Eksik dosya yayımlanmadı.",
        errorLyrics: "Seçili altyazı MP3 sözlerine eklenemedi. Eksik dosya yayımlanmadı.",
        errorFileSafety: "Biten dosya doğrulanamadı veya seçili klasöre güvenle yerleştirilemedi."
    )

    static let ru = VideoDownloaderStrings(
        pageTitle: "Загрузчик видео", hubDescription: "Скачивайте одно общедоступное видео или MP3 с выбором качества и субтитров",
        panelCaption: "Сохраните общедоступную ссылку как MP4 или MP3",
        urlPlaceholder: "Вставьте общедоступный HTTP- или HTTPS-адрес", urlHelp: "Адрес проверяется только после валидации, не сохраняется и не попадает в аргументы процесса.",
        paste: "Вставить", inspecting: "Проверка медиа…", video: "Видео", mp3: "MP3", quality: "Качество видео", best: "Лучшее",
        heightFormat: "%dp", qualityFallbackFormat: "%dp недоступно; вместо него выбрано %dp.",
        subtitles: "Субтитры", none: "Нет", manual: "Обычные", automatic: "Автоматические",
        destination: "Папка загрузки", choose: "Выбрать…", showInPanel: "Показывать в панели меню",
        settingsCaption: "Загрузка готовится в закрытой временной папке; в выбранную папку попадает только готовый MP4 или MP3.",
        defaultLocation: "Папка загрузки по умолчанию", resetDownloads: "Сбросить на «Загрузки»",
        embedThumbnail: "Встроить миниатюру в MP4 / обложку в MP3", embedMetadata: "Встроить метаданные",
        embedChapters: "Встроить главы в MP4", embedSubtitle: "Встроить выбранные субтитры в MP4",
        lyrics: "Добавить текст выбранных субтитров как слова MP3", dependencies: "Инструменты загрузки",
        missingToolsFormat: "Отсутствуют: %@", installMissingTools: "Установить недостающие инструменты", setUpDownloader: "Настроить загрузчик",
        brewSetupNote: "Homebrew установит только отсутствующие yt-dlp и ffmpeg. Операцию можно отменить.",
        terminalSetupNote: "В Terminal откроется официальная установка Homebrew; она может запросить подтверждение или пароль, затем установит yt-dlp и ffmpeg.",
        checkingTools: "Проверка инструментов…", downloadVideo: "Скачать видео", downloadMP3: "Скачать MP3", downloading: "Загрузка",
        percentFormat: "%.0f%%", speedFormat: "%@/с", etaFormat: "Осталось %@", finalizing: "Завершение…", cancel: "Отменить",
        cancelling: "Отмена…", complete: "Загрузка завершена", downloadAnother: "Скачать ещё", revealFinder: "Показать в Finder",
        retry: "Повторить", cancelled: "Загрузка отменена", failureTitle: "Не удалось завершить загрузку", uploader: "Автор",
        duration: "Длительность", thumbnail: "Миниатюра медиа",
        errorURLInvalid: "Введите полный общедоступный HTTP- или HTTPS-адрес медиа.", errorURLTooLong: "Этот адрес слишком длинный для безопасной проверки.",
        errorURLControl: "Адрес содержит перенос строки или управляющий символ.", errorURLCredentials: "Адреса с именем пользователя или паролем не поддерживаются.",
        errorInspectionTimeout: "Проверка заняла слишком много времени. Проверьте ссылку и повторите.",
        errorInspectionFailed: "Не удалось проверить медиа. Убедитесь, что оно общедоступно.",
        errorInspectionTooLarge: "Сайт вернул слишком много данных для безопасной обработки.", errorInspectionMalformed: "Данные yt-dlp о медиа непригодны.",
        errorPlaylist: "Плейлисты, каналы и коллекции не поддерживаются. Вставьте один медиаобъект.", errorLive: "Прямые и предстоящие трансляции не поддерживаются.",
        errorDRM: "Медиа с DRM скачать нельзя.", errorRestricted: "Закрытые, платные и требующие входа медиа не поддерживаются.",
        errorNoFormats: "Подходящие форматы медиа не найдены.", errorNoVideo: "У объекта нет подходящего видеопотока. Выберите MP3.",
        errorNoAudio: "У объекта нет подходящего аудиопотока.", errorMissingDependencies: "Для загрузки нужны yt-dlp и ffmpeg.",
        errorSetupBusy: "Уже выполняется другая операция Homebrew. Повторите после её завершения.",
        errorSetupFailed: "Не удалось установить инструменты. Проверьте Homebrew и повторите.",
        errorTerminalPermission: "Не удалось открыть Terminal. Разрешите автоматизацию Terminal в Системных настройках.",
        errorDownloadFailed: "Сбой загрузки. Проверьте, что ссылка всё ещё общедоступна.",
        errorRemux: "Выбранные потоки нельзя объединить или перемультиплексировать в MP4 без перекодирования. Выберите другое качество.",
        errorSubtitle: "Не удалось скачать и встроить выбранные субтитры. Неполный файл не опубликован.",
        errorOptionalData: "Не удалось встроить выбранную обложку, метаданные или главы. Неполный файл не опубликован.",
        errorLyrics: "Не удалось добавить субтитры как слова MP3. Неполный файл не опубликован.",
        errorFileSafety: "Не удалось проверить или безопасно поместить готовый файл в выбранную папку."
    )

    static let es = VideoDownloaderStrings(
        pageTitle: "Descargador de vídeos", hubDescription: "Descarga un vídeo público o MP3 eligiendo calidad y subtítulos",
        panelCaption: "Guarda un enlace público como MP4 o MP3",
        urlPlaceholder: "Pega una URL pública HTTP o HTTPS", urlHelp: "La URL solo se inspecciona cuando es válida; no se guarda ni se incluye en argumentos del proceso.",
        paste: "Pegar", inspecting: "Inspeccionando…", video: "Vídeo", mp3: "MP3", quality: "Calidad de vídeo", best: "Mejor",
        heightFormat: "%dp", qualityFallbackFormat: "%dp no estaba disponible; se seleccionó %dp.",
        subtitles: "Subtítulos", none: "Ninguno", manual: "Manual", automatic: "Automático",
        destination: "Carpeta de descargas", choose: "Elegir…", showInPanel: "Mostrar en el panel del menú",
        settingsCaption: "La descarga se prepara en privado y solo el MP4 o MP3 terminado se coloca en tu carpeta.",
        defaultLocation: "Ubicación predeterminada", resetDownloads: "Restablecer a Descargas",
        embedThumbnail: "Incrustar miniatura en MP4 / portada en MP3", embedMetadata: "Incrustar metadatos", embedChapters: "Incrustar capítulos en MP4",
        embedSubtitle: "Incrustar el subtítulo seleccionado en MP4", lyrics: "Añadir el texto del subtítulo como letra del MP3", dependencies: "Herramientas de descarga",
        missingToolsFormat: "Faltan: %@", installMissingTools: "Instalar herramientas que faltan", setUpDownloader: "Configurar descargador",
        brewSetupNote: "Homebrew instala solo yt-dlp o ffmpeg si faltan. Puedes cancelar mientras se ejecuta.",
        terminalSetupNote: "Terminal abrirá la instalación oficial de Homebrew y puede pedir confirmación o contraseña; después instalará yt-dlp y ffmpeg.",
        checkingTools: "Comprobando herramientas…", downloadVideo: "Descargar vídeo", downloadMP3: "Descargar MP3", downloading: "Descargando",
        percentFormat: "%.0f%%", speedFormat: "%@/s", etaFormat: "Quedan %@", finalizing: "Finalizando…", cancel: "Cancelar", cancelling: "Cancelando…",
        complete: "Descarga completada", downloadAnother: "Descargar otro", revealFinder: "Mostrar en Finder", retry: "Reintentar", cancelled: "Descarga cancelada",
        failureTitle: "No se pudo completar la descarga", uploader: "Autor", duration: "Duración", thumbnail: "Miniatura del contenido",
        errorURLInvalid: "Introduce una URL pública HTTP o HTTPS completa.", errorURLTooLong: "Esta URL es demasiado larga para inspeccionarla con seguridad.",
        errorURLControl: "La URL contiene un salto de línea o carácter de control.", errorURLCredentials: "No se admiten URL con usuario o contraseña.",
        errorInspectionTimeout: "La inspección tardó demasiado. Comprueba el enlace e inténtalo de nuevo.", errorInspectionFailed: "No se pudo inspeccionar. Comprueba que sea público y esté disponible.",
        errorInspectionTooLarge: "El sitio devolvió demasiada información para procesarla con seguridad.", errorInspectionMalformed: "La información devuelta por yt-dlp no se pudo usar.",
        errorPlaylist: "No se admiten listas, canales ni colecciones. Pega un solo elemento.", errorLive: "No se admiten emisiones en directo o futuras.",
        errorDRM: "No se puede descargar contenido protegido con DRM.", errorRestricted: "No se admite contenido privado, de pago o que requiera iniciar sesión.",
        errorNoFormats: "No se encontraron formatos utilizables.", errorNoVideo: "Este elemento no tiene vídeo utilizable. Elige MP3.",
        errorNoAudio: "Este elemento no tiene audio utilizable.", errorMissingDependencies: "Se necesitan yt-dlp y ffmpeg para descargar.",
        errorSetupBusy: "Ya hay otra operación de Homebrew. Inténtalo cuando termine.", errorSetupFailed: "No se pudieron instalar las herramientas. Comprueba Homebrew.",
        errorTerminalPermission: "No se pudo abrir Terminal. Permite Automatización de Terminal en Ajustes del Sistema.",
        errorDownloadFailed: "La descarga falló. Comprueba que el enlace siga siendo público y disponible.",
        errorRemux: "Los flujos elegidos no pueden combinarse o remultiplexarse a MP4 sin transcodificar. Elige otra calidad.",
        errorSubtitle: "No se pudo descargar e integrar el subtítulo elegido. No se publicó ningún archivo incompleto.",
        errorOptionalData: "No se pudo integrar la portada, los metadatos o los capítulos solicitados. No se publicó ningún archivo incompleto.",
        errorLyrics: "No se pudieron añadir los subtítulos como letra del MP3. No se publicó ningún archivo incompleto.",
        errorFileSafety: "No se pudo verificar o colocar con seguridad el archivo final en la carpeta elegida."
    )

    static let de = VideoDownloaderStrings(
        pageTitle: "Video-Downloader", hubDescription: "Ein öffentliches Video oder MP3 mit Qualitäts- und Untertitelauswahl laden",
        panelCaption: "Einen öffentlichen Medienlink als MP4 oder MP3 sichern",
        urlPlaceholder: "Öffentliche HTTP- oder HTTPS-Medien-URL einfügen", urlHelp: "Die URL wird erst nach gültiger Eingabe geprüft, nicht gespeichert und nicht als Prozessargument verwendet.",
        paste: "Einfügen", inspecting: "Medium wird geprüft…", video: "Video", mp3: "MP3", quality: "Videoqualität", best: "Beste",
        heightFormat: "%dp", qualityFallbackFormat: "%dp war nicht verfügbar; stattdessen wurde %dp ausgewählt.",
        subtitles: "Untertitel", none: "Keine", manual: "Manuell", automatic: "Automatisch",
        destination: "Downloadordner", choose: "Auswählen…", showInPanel: "Im Menüpanel anzeigen",
        settingsCaption: "Downloads werden privat vorbereitet; nur die fertige MP4- oder MP3-Datei kommt in deinen Ordner.",
        defaultLocation: "Standard-Downloadort", resetDownloads: "Auf Downloads zurücksetzen",
        embedThumbnail: "Vorschaubild in MP4 / Cover in MP3 einbetten", embedMetadata: "Metadaten einbetten", embedChapters: "Kapitel in MP4 einbetten",
        embedSubtitle: "Gewählten Untertitel in MP4 einbetten", lyrics: "Gewählten Untertiteltext als MP3-Liedtext hinzufügen", dependencies: "Downloader-Werkzeuge",
        missingToolsFormat: "Fehlt: %@", installMissingTools: "Fehlende Werkzeuge installieren", setUpDownloader: "Downloader einrichten",
        brewSetupNote: "Homebrew installiert nur fehlendes yt-dlp oder ffmpeg. Der Vorgang kann abgebrochen werden.",
        terminalSetupNote: "Terminal öffnet die offizielle Homebrew-Einrichtung, kann Bestätigung oder Passwort verlangen und installiert danach yt-dlp und ffmpeg.",
        checkingTools: "Downloader-Werkzeuge werden geprüft…", downloadVideo: "Video laden", downloadMP3: "MP3 laden", downloading: "Wird geladen",
        percentFormat: "%.0f%%", speedFormat: "%@/s", etaFormat: "Restzeit %@", finalizing: "Wird fertiggestellt…", cancel: "Abbrechen", cancelling: "Wird abgebrochen…",
        complete: "Download abgeschlossen", downloadAnother: "Weiteren laden", revealFinder: "Im Finder zeigen", retry: "Erneut versuchen", cancelled: "Download abgebrochen",
        failureTitle: "Download konnte nicht abgeschlossen werden", uploader: "Uploader", duration: "Dauer", thumbnail: "Medienvorschau",
        errorURLInvalid: "Gib eine vollständige öffentliche HTTP- oder HTTPS-Medien-URL ein.", errorURLTooLong: "Diese URL ist für eine sichere Prüfung zu lang.",
        errorURLControl: "Die URL enthält einen Zeilenumbruch oder ein Steuerzeichen.", errorURLCredentials: "URLs mit Benutzername oder Passwort werden nicht unterstützt.",
        errorInspectionTimeout: "Die Prüfung dauerte zu lange. Prüfe den Link und versuche es erneut.", errorInspectionFailed: "Das Medium konnte nicht geprüft werden. Stelle sicher, dass es öffentlich verfügbar ist.",
        errorInspectionTooLarge: "Die Website lieferte zu viele Mediendaten für eine sichere Verarbeitung.", errorInspectionMalformed: "Die von yt-dlp gelieferten Mediendaten waren nicht nutzbar.",
        errorPlaylist: "Playlists, Kanäle und Sammlungen werden nicht unterstützt. Füge ein Medium ein.", errorLive: "Live- und bevorstehende Streams werden nicht unterstützt.",
        errorDRM: "DRM-geschützte Medien können nicht geladen werden.", errorRestricted: "Private, kostenpflichtige oder an Anmeldung gebundene Medien werden nicht unterstützt.",
        errorNoFormats: "Keine nutzbaren Medienformate gefunden.", errorNoVideo: "Dieses Medium hat keinen nutzbaren Videostream. Wähle MP3.",
        errorNoAudio: "Dieses Medium hat keinen nutzbaren Audiostream.", errorMissingDependencies: "yt-dlp und ffmpeg werden beide zum Laden benötigt.",
        errorSetupBusy: "Ein anderer Homebrew-Vorgang läuft bereits. Versuche es danach erneut.", errorSetupFailed: "Die Werkzeuge konnten nicht installiert werden. Prüfe Homebrew.",
        errorTerminalPermission: "Terminal konnte nicht geöffnet werden. Erlaube Terminal-Automation in den Systemeinstellungen.",
        errorDownloadFailed: "Der Download ist fehlgeschlagen. Prüfe, ob der Link weiter öffentlich verfügbar ist.",
        errorRemux: "Die gewählten Streams lassen sich ohne Transkodierung nicht in MP4 zusammenführen oder umpacken. Wähle eine andere Qualität.",
        errorSubtitle: "Der gewählte Untertitel konnte nicht geladen und eingebettet werden. Keine unvollständige Datei wurde veröffentlicht.",
        errorOptionalData: "Das gewünschte Titelbild, die Metadaten oder Kapitel konnten nicht eingebettet werden. Keine unvollständige Datei wurde veröffentlicht.",
        errorLyrics: "Die Untertitel konnten nicht als MP3-Liedtext hinzugefügt werden. Keine unvollständige Datei wurde veröffentlicht.",
        errorFileSafety: "Die fertige Datei konnte nicht geprüft oder sicher im gewählten Ordner abgelegt werden."
    )

    static let fr = VideoDownloaderStrings(
        pageTitle: "Téléchargeur vidéo", hubDescription: "Téléchargez une vidéo publique ou un MP3 avec choix de qualité et de sous-titres",
        panelCaption: "Enregistrez un lien public en MP4 ou MP3",
        urlPlaceholder: "Collez une URL média HTTP ou HTTPS publique", urlHelp: "L’URL n’est inspectée qu’une fois valide ; elle n’est ni enregistrée ni placée dans les arguments du processus.",
        paste: "Coller", inspecting: "Inspection du média…", video: "Vidéo", mp3: "MP3", quality: "Qualité vidéo", best: "Meilleure",
        heightFormat: "%dp", qualityFallbackFormat: "%dp n’était pas disponible ; %dp a été sélectionné à la place.",
        subtitles: "Sous-titres", none: "Aucun", manual: "Manuels", automatic: "Automatiques",
        destination: "Dossier de téléchargement", choose: "Choisir…", showInPanel: "Afficher dans le panneau du menu",
        settingsCaption: "Le téléchargement est préparé dans un espace privé ; seul le MP4 ou MP3 terminé rejoint votre dossier.",
        defaultLocation: "Emplacement par défaut", resetDownloads: "Rétablir Téléchargements",
        embedThumbnail: "Intégrer la miniature au MP4 / la pochette au MP3", embedMetadata: "Intégrer les métadonnées", embedChapters: "Intégrer les chapitres au MP4",
        embedSubtitle: "Intégrer le sous-titre choisi au MP4", lyrics: "Ajouter le texte du sous-titre comme paroles du MP3", dependencies: "Outils de téléchargement",
        missingToolsFormat: "Manquant : %@", installMissingTools: "Installer les outils manquants", setUpDownloader: "Configurer le téléchargeur",
        brewSetupNote: "Homebrew installe uniquement yt-dlp ou ffmpeg s’ils manquent. Vous pouvez annuler pendant l’opération.",
        terminalSetupNote: "Terminal ouvre l’installation officielle de Homebrew, peut demander confirmation ou mot de passe, puis installe yt-dlp et ffmpeg.",
        checkingTools: "Vérification des outils…", downloadVideo: "Télécharger la vidéo", downloadMP3: "Télécharger le MP3", downloading: "Téléchargement",
        percentFormat: "%.0f%%", speedFormat: "%@/s", etaFormat: "Reste %@", finalizing: "Finalisation…", cancel: "Annuler", cancelling: "Annulation…",
        complete: "Téléchargement terminé", downloadAnother: "En télécharger un autre", revealFinder: "Afficher dans Finder", retry: "Réessayer", cancelled: "Téléchargement annulé",
        failureTitle: "Impossible de terminer le téléchargement", uploader: "Auteur", duration: "Durée", thumbnail: "Miniature du média",
        errorURLInvalid: "Saisissez une URL média HTTP ou HTTPS publique complète.", errorURLTooLong: "Cette URL est trop longue pour être inspectée en sécurité.",
        errorURLControl: "L’URL contient un saut de ligne ou un caractère de contrôle.", errorURLCredentials: "Les URL contenant un nom d’utilisateur ou un mot de passe ne sont pas prises en charge.",
        errorInspectionTimeout: "L’inspection a pris trop de temps. Vérifiez le lien et réessayez.", errorInspectionFailed: "Le média n’a pas pu être inspecté. Vérifiez qu’il est public et disponible.",
        errorInspectionTooLarge: "Le site a renvoyé trop d’informations pour un traitement sûr.", errorInspectionMalformed: "Les informations renvoyées par yt-dlp sont inutilisables.",
        errorPlaylist: "Les listes, chaînes et collections ne sont pas prises en charge. Collez un seul média.", errorLive: "Les directs et diffusions à venir ne sont pas pris en charge.",
        errorDRM: "Les médias protégés par DRM ne peuvent pas être téléchargés.", errorRestricted: "Les médias privés, payants ou soumis à connexion ne sont pas pris en charge.",
        errorNoFormats: "Aucun format média utilisable n’a été trouvé.", errorNoVideo: "Ce média n’a pas de flux vidéo utilisable. Choisissez MP3.",
        errorNoAudio: "Ce média n’a pas de flux audio utilisable.", errorMissingDependencies: "yt-dlp et ffmpeg sont nécessaires au téléchargement.",
        errorSetupBusy: "Une autre opération Homebrew est en cours. Réessayez après sa fin.", errorSetupFailed: "Les outils n’ont pas pu être installés. Vérifiez Homebrew.",
        errorTerminalPermission: "Terminal n’a pas pu s’ouvrir. Autorisez l’automatisation de Terminal dans Réglages Système.",
        errorDownloadFailed: "Le téléchargement a échoué. Vérifiez que le lien reste public et disponible.",
        errorRemux: "Les flux choisis ne peuvent pas être fusionnés ou remultiplexés en MP4 sans transcodage. Choisissez une autre qualité.",
        errorSubtitle: "Le sous-titre choisi n’a pas pu être téléchargé et intégré. Aucun fichier incomplet n’a été publié.",
        errorOptionalData: "La pochette, les métadonnées ou les chapitres demandés n’ont pas pu être intégrés. Aucun fichier incomplet n’a été publié.",
        errorLyrics: "Les sous-titres n’ont pas pu être ajoutés comme paroles MP3. Aucun fichier incomplet n’a été publié.",
        errorFileSafety: "Le fichier final n’a pas pu être vérifié ou placé en sécurité dans le dossier choisi."
    )

    static let it = VideoDownloaderStrings(
        pageTitle: "Downloader video", hubDescription: "Scarica un video pubblico o MP3 scegliendo qualità e sottotitoli",
        panelCaption: "Salva un link pubblico come MP4 o MP3",
        urlPlaceholder: "Incolla un URL multimediale HTTP o HTTPS pubblico", urlHelp: "L’URL viene ispezionato solo se valido; non viene salvato né inserito negli argomenti del processo.",
        paste: "Incolla", inspecting: "Ispezione del contenuto…", video: "Video", mp3: "MP3", quality: "Qualità video", best: "Migliore",
        heightFormat: "%dp", qualityFallbackFormat: "%dp non era disponibile; è stato selezionato %dp.",
        subtitles: "Sottotitoli", none: "Nessuno", manual: "Manuali", automatic: "Automatici",
        destination: "Cartella download", choose: "Scegli…", showInPanel: "Mostra nel pannello menu",
        settingsCaption: "Il download viene preparato in privato; nella cartella arriva solo l’MP4 o MP3 completo.",
        defaultLocation: "Posizione download predefinita", resetDownloads: "Ripristina Download",
        embedThumbnail: "Incorpora miniatura in MP4 / copertina in MP3", embedMetadata: "Incorpora metadati", embedChapters: "Incorpora capitoli in MP4",
        embedSubtitle: "Incorpora il sottotitolo scelto in MP4", lyrics: "Aggiungi il testo del sottotitolo come parole MP3", dependencies: "Strumenti di download",
        missingToolsFormat: "Manca: %@", installMissingTools: "Installa strumenti mancanti", setUpDownloader: "Configura downloader",
        brewSetupNote: "Homebrew installa solo yt-dlp o ffmpeg mancanti. Puoi annullare durante l’operazione.",
        terminalSetupNote: "Terminale apre l’installazione ufficiale di Homebrew, può chiedere conferma o password e poi installa yt-dlp e ffmpeg.",
        checkingTools: "Verifica strumenti…", downloadVideo: "Scarica video", downloadMP3: "Scarica MP3", downloading: "Download",
        percentFormat: "%.0f%%", speedFormat: "%@/s", etaFormat: "Restano %@", finalizing: "Finalizzazione…", cancel: "Annulla", cancelling: "Annullamento…",
        complete: "Download completato", downloadAnother: "Scarica altro", revealFinder: "Mostra nel Finder", retry: "Riprova", cancelled: "Download annullato",
        failureTitle: "Impossibile completare il download", uploader: "Autore", duration: "Durata", thumbnail: "Miniatura del contenuto",
        errorURLInvalid: "Inserisci un URL multimediale HTTP o HTTPS pubblico completo.", errorURLTooLong: "Questo URL è troppo lungo per un’ispezione sicura.",
        errorURLControl: "L’URL contiene un’interruzione di riga o carattere di controllo.", errorURLCredentials: "Gli URL con nome utente o password non sono supportati.",
        errorInspectionTimeout: "L’ispezione ha richiesto troppo tempo. Controlla il link e riprova.", errorInspectionFailed: "Impossibile ispezionare il contenuto. Verifica che sia pubblico e disponibile.",
        errorInspectionTooLarge: "Il sito ha restituito troppe informazioni per elaborarle in sicurezza.", errorInspectionMalformed: "Le informazioni restituite da yt-dlp non erano utilizzabili.",
        errorPlaylist: "Playlist, canali e raccolte non sono supportati. Incolla un solo elemento.", errorLive: "Dirette e trasmissioni future non sono supportate.",
        errorDRM: "I contenuti protetti da DRM non possono essere scaricati.", errorRestricted: "I contenuti privati, a pagamento o con accesso non sono supportati.",
        errorNoFormats: "Nessun formato utilizzabile trovato.", errorNoVideo: "Questo elemento non ha un flusso video utilizzabile. Scegli MP3.",
        errorNoAudio: "Questo elemento non ha un flusso audio utilizzabile.", errorMissingDependencies: "Per scaricare servono yt-dlp e ffmpeg.",
        errorSetupBusy: "È già in corso un’altra operazione Homebrew. Riprova quando termina.", errorSetupFailed: "Impossibile installare gli strumenti. Controlla Homebrew.",
        errorTerminalPermission: "Impossibile aprire Terminale. Consenti l’automazione di Terminale in Impostazioni di Sistema.",
        errorDownloadFailed: "Il download non è riuscito. Verifica che il link sia ancora pubblico e disponibile.",
        errorRemux: "I flussi scelti non possono essere uniti o rimultiplessati in MP4 senza transcodifica. Scegli un’altra qualità.",
        errorSubtitle: "Non è stato possibile scaricare e incorporare il sottotitolo scelto. Nessun file incompleto è stato pubblicato.",
        errorOptionalData: "Non è stato possibile incorporare la copertina, i metadati o i capitoli richiesti. Nessun file incompleto è stato pubblicato.",
        errorLyrics: "Impossibile aggiungere i sottotitoli come parole MP3. Nessun file incompleto è stato pubblicato.",
        errorFileSafety: "Impossibile verificare o collocare in sicurezza il file finale nella cartella scelta."
    )

    static let ja = VideoDownloaderStrings(
        pageTitle: "ビデオダウンローダー", hubDescription: "公開動画を画質と字幕を選んでビデオまたはMP3でダウンロード",
        panelCaption: "公開メディアリンクをMP4またはMP3で保存",
        urlPlaceholder: "公開HTTPまたはHTTPSメディアURLを貼り付け", urlHelp: "URLは有効になってから調べます。保存せず、プロセス引数にも入れません。",
        paste: "ペースト", inspecting: "メディアを確認中…", video: "ビデオ", mp3: "MP3", quality: "ビデオ画質", best: "最高",
        heightFormat: "%dp", qualityFallbackFormat: "%dpは利用できなかったため、代わりに%dpを選択しました。",
        subtitles: "字幕", none: "なし", manual: "通常字幕", automatic: "自動字幕",
        destination: "ダウンロード先", choose: "選択…", showInPanel: "メニューパネルに表示",
        settingsCaption: "非公開の一時領域で処理し、完成したMP4またはMP3だけを選択フォルダに置きます。",
        defaultLocation: "標準のダウンロード先", resetDownloads: "ダウンロードに戻す",
        embedThumbnail: "MP4にサムネイル／MP3にカバーを埋め込む", embedMetadata: "メタデータを埋め込む", embedChapters: "MP4にチャプターを埋め込む",
        embedSubtitle: "選択した字幕をMP4に埋め込む", lyrics: "選択した字幕をMP3の歌詞として追加", dependencies: "ダウンロードツール",
        missingToolsFormat: "不足：%@", installMissingTools: "不足ツールをインストール", setUpDownloader: "ダウンローダーを設定",
        brewSetupNote: "Homebrewは不足しているyt-dlpとffmpegだけをインストールします。実行中にキャンセルできます。",
        terminalSetupNote: "Terminalで公式Homebrew設定を開きます。確認やパスワードを求めた後、yt-dlpとffmpegをインストールします。",
        checkingTools: "ツールを確認中…", downloadVideo: "ビデオをダウンロード", downloadMP3: "MP3をダウンロード", downloading: "ダウンロード中",
        percentFormat: "%.0f%%", speedFormat: "%@/秒", etaFormat: "残り%@", finalizing: "仕上げ中…", cancel: "キャンセル", cancelling: "キャンセル中…",
        complete: "ダウンロード完了", downloadAnother: "別の項目をダウンロード", revealFinder: "Finderに表示", retry: "再試行", cancelled: "ダウンロードをキャンセルしました",
        failureTitle: "ダウンロードを完了できませんでした", uploader: "投稿者", duration: "再生時間", thumbnail: "メディアのサムネイル",
        errorURLInvalid: "完全な公開HTTPまたはHTTPSメディアURLを入力してください。", errorURLTooLong: "このURLは安全に確認するには長すぎます。",
        errorURLControl: "URLに改行または制御文字があります。", errorURLCredentials: "ユーザー名やパスワードを含むURLには対応していません。",
        errorInspectionTimeout: "確認に時間がかかりすぎました。リンクを確認して再試行してください。", errorInspectionFailed: "メディアを確認できませんでした。公開され利用可能か確認してください。",
        errorInspectionTooLarge: "サイトから安全に処理できる量を超える情報が返されました。", errorInspectionMalformed: "yt-dlpから返された情報を使用できませんでした。",
        errorPlaylist: "プレイリスト、チャンネル、コレクションには対応していません。1件のメディアを貼り付けてください。", errorLive: "ライブ配信と配信予定には対応していません。",
        errorDRM: "DRMで保護されたメディアはダウンロードできません。", errorRestricted: "非公開、有料、ログイン制限付きメディアには対応していません。",
        errorNoFormats: "利用できるメディア形式が見つかりません。", errorNoVideo: "利用できるビデオストリームがありません。MP3を選んでください。",
        errorNoAudio: "利用できるオーディオストリームがありません。", errorMissingDependencies: "ダウンロードにはyt-dlpとffmpegが必要です。",
        errorSetupBusy: "別のHomebrew操作が実行中です。完了後に再試行してください。", errorSetupFailed: "ツールをインストールできませんでした。Homebrewを確認してください。",
        errorTerminalPermission: "Terminalを開けませんでした。システム設定でTerminalのオートメーションを許可してください。",
        errorDownloadFailed: "ダウンロードに失敗しました。リンクが引き続き公開されているか確認してください。",
        errorRemux: "選択したストリームは、変換せずにMP4へ結合または再多重化できません。別の画質を選んでください。",
        errorSubtitle: "選択した字幕をダウンロードして埋め込めませんでした。不完全なファイルは公開していません。",
        errorOptionalData: "指定したアートワーク、メタデータ、またはチャプターを埋め込めませんでした。不完全なファイルは公開していません。",
        errorLyrics: "字幕をMP3歌詞として追加できませんでした。不完全なファイルは公開していません。",
        errorFileSafety: "完成ファイルを確認または選択フォルダへ安全に配置できませんでした。"
    )

    static let ko = VideoDownloaderStrings(
        pageTitle: "비디오 다운로더", hubDescription: "공개 비디오 하나를 화질과 자막을 골라 비디오 또는 MP3로 다운로드",
        panelCaption: "공개 미디어 링크를 MP4 또는 MP3로 저장",
        urlPlaceholder: "공개 HTTP 또는 HTTPS 미디어 URL 붙여넣기", urlHelp: "URL은 유효해진 뒤에만 검사하며 저장하거나 프로세스 인수에 넣지 않습니다.",
        paste: "붙여넣기", inspecting: "미디어 검사 중…", video: "비디오", mp3: "MP3", quality: "비디오 화질", best: "최고",
        heightFormat: "%dp", qualityFallbackFormat: "%dp를 사용할 수 없어 대신 %dp가 선택되었습니다.",
        subtitles: "자막", none: "없음", manual: "일반", automatic: "자동",
        destination: "다운로드 폴더", choose: "선택…", showInPanel: "메뉴 패널에 표시",
        settingsCaption: "비공개 임시 공간에서 준비하며 완료된 MP4 또는 MP3만 선택한 폴더에 놓습니다.",
        defaultLocation: "기본 다운로드 위치", resetDownloads: "다운로드로 재설정",
        embedThumbnail: "MP4에 썸네일 / MP3에 표지 삽입", embedMetadata: "메타데이터 삽입", embedChapters: "MP4에 챕터 삽입",
        embedSubtitle: "선택한 자막을 MP4에 삽입", lyrics: "선택한 자막을 MP3 가사로 추가", dependencies: "다운로드 도구",
        missingToolsFormat: "누락: %@", installMissingTools: "누락 도구 설치", setUpDownloader: "다운로더 설정",
        brewSetupNote: "Homebrew는 누락된 yt-dlp와 ffmpeg만 설치합니다. 실행 중 취소할 수 있습니다.",
        terminalSetupNote: "Terminal에서 공식 Homebrew 설정을 열며 확인이나 암호를 요청할 수 있습니다. 이후 yt-dlp와 ffmpeg를 설치합니다.",
        checkingTools: "다운로드 도구 확인 중…", downloadVideo: "비디오 다운로드", downloadMP3: "MP3 다운로드", downloading: "다운로드 중",
        percentFormat: "%.0f%%", speedFormat: "%@/초", etaFormat: "남은 시간 %@", finalizing: "마무리 중…", cancel: "취소", cancelling: "취소 중…",
        complete: "다운로드 완료", downloadAnother: "다른 항목 다운로드", revealFinder: "Finder에서 보기", retry: "다시 시도", cancelled: "다운로드 취소됨",
        failureTitle: "다운로드를 완료할 수 없음", uploader: "업로더", duration: "길이", thumbnail: "미디어 썸네일",
        errorURLInvalid: "완전한 공개 HTTP 또는 HTTPS 미디어 URL을 입력하세요.", errorURLTooLong: "이 URL은 안전하게 검사하기에는 너무 깁니다.",
        errorURLControl: "URL에 줄바꿈이나 제어 문자가 있습니다.", errorURLCredentials: "사용자 이름이나 암호가 든 URL은 지원하지 않습니다.",
        errorInspectionTimeout: "검사가 너무 오래 걸렸습니다. 링크를 확인하고 다시 시도하세요.", errorInspectionFailed: "미디어를 검사할 수 없습니다. 공개되어 있고 이용 가능한지 확인하세요.",
        errorInspectionTooLarge: "사이트가 안전하게 처리할 수 있는 양보다 많은 정보를 반환했습니다.", errorInspectionMalformed: "yt-dlp가 반환한 미디어 정보를 사용할 수 없습니다.",
        errorPlaylist: "재생목록, 채널, 모음은 지원하지 않습니다. 미디어 한 개를 붙여넣으세요.", errorLive: "라이브 및 예정 스트림은 지원하지 않습니다.",
        errorDRM: "DRM 보호 미디어는 다운로드할 수 없습니다.", errorRestricted: "비공개, 유료 또는 로그인 제한 미디어는 지원하지 않습니다.",
        errorNoFormats: "사용 가능한 미디어 형식을 찾지 못했습니다.", errorNoVideo: "사용 가능한 비디오 스트림이 없습니다. MP3를 선택하세요.",
        errorNoAudio: "사용 가능한 오디오 스트림이 없습니다.", errorMissingDependencies: "다운로드하려면 yt-dlp와 ffmpeg가 모두 필요합니다.",
        errorSetupBusy: "다른 Homebrew 작업이 실행 중입니다. 끝난 뒤 다시 시도하세요.", errorSetupFailed: "도구를 설치할 수 없습니다. Homebrew를 확인하세요.",
        errorTerminalPermission: "Terminal을 열 수 없습니다. 시스템 설정에서 Terminal 자동화를 허용하세요.",
        errorDownloadFailed: "다운로드에 실패했습니다. 링크가 계속 공개되어 있고 이용 가능한지 확인하세요.",
        errorRemux: "선택한 스트림은 트랜스코딩 없이 MP4로 병합하거나 리먹스할 수 없습니다. 다른 화질을 고르세요.",
        errorSubtitle: "선택한 자막을 다운로드하여 삽입할 수 없습니다. 불완전한 파일은 게시하지 않았습니다.",
        errorOptionalData: "요청한 표지, 메타데이터 또는 챕터를 삽입할 수 없습니다. 불완전한 파일은 게시하지 않았습니다.",
        errorLyrics: "자막을 MP3 가사로 추가할 수 없습니다. 불완전한 파일은 게시하지 않았습니다.",
        errorFileSafety: "완료된 파일을 확인하거나 선택한 폴더에 안전하게 놓을 수 없습니다."
    )

    static let zhHans = VideoDownloaderStrings(
        pageTitle: "视频下载器", hubDescription: "下载一个公开视频或 MP3，并选择画质和字幕", panelCaption: "将公开媒体链接保存为 MP4 或 MP3",
        urlPlaceholder: "粘贴公开的 HTTP 或 HTTPS 媒体网址",
        urlHelp: "网址仅在有效后开始检查；不会保存，也不会放入进程参数。", paste: "粘贴", inspecting: "正在检查媒体…", video: "视频", mp3: "MP3",
        quality: "视频画质", best: "最佳", heightFormat: "%dp", qualityFallbackFormat: "%dp 不可用，已改选 %dp。",
        subtitles: "字幕", none: "无", manual: "人工字幕", automatic: "自动字幕",
        destination: "下载文件夹", choose: "选择…", showInPanel: "在菜单面板中显示",
        settingsCaption: "下载会在私有临时区域中处理，只有完成的 MP4 或 MP3 会放入所选文件夹。", defaultLocation: "默认下载位置", resetDownloads: "重置为“下载”",
        embedThumbnail: "在 MP4 中嵌入缩略图 / 在 MP3 中嵌入封面", embedMetadata: "嵌入元数据", embedChapters: "在 MP4 中嵌入章节",
        embedSubtitle: "在 MP4 中嵌入所选字幕", lyrics: "将所选字幕文本添加为 MP3 歌词", dependencies: "下载工具",
        missingToolsFormat: "缺少：%@", installMissingTools: "安装缺少的工具", setUpDownloader: "设置下载器",
        brewSetupNote: "Homebrew 只安装缺少的 yt-dlp 和 ffmpeg。运行期间可以取消。",
        terminalSetupNote: "Terminal 将打开官方 Homebrew 安装，可能要求确认或输入密码，随后安装 yt-dlp 和 ffmpeg。",
        checkingTools: "正在检查下载工具…", downloadVideo: "下载视频", downloadMP3: "下载 MP3", downloading: "正在下载",
        percentFormat: "%.0f%%", speedFormat: "%@/秒", etaFormat: "剩余 %@", finalizing: "正在完成处理…", cancel: "取消", cancelling: "正在取消…",
        complete: "下载完成", downloadAnother: "下载另一个", revealFinder: "在 Finder 中显示", retry: "重试", cancelled: "下载已取消",
        failureTitle: "无法完成下载", uploader: "上传者", duration: "时长", thumbnail: "媒体缩略图",
        errorURLInvalid: "请输入完整的公开 HTTP 或 HTTPS 媒体网址。", errorURLTooLong: "此网址过长，无法安全检查。", errorURLControl: "网址包含换行符或控制字符。",
        errorURLCredentials: "不支持包含用户名或密码的网址。", errorInspectionTimeout: "检查时间过长。请检查链接后重试。",
        errorInspectionFailed: "无法检查媒体。请确认它公开且可用。", errorInspectionTooLarge: "网站返回的信息过多，无法安全处理。",
        errorInspectionMalformed: "yt-dlp 返回的媒体信息无法使用。", errorPlaylist: "不支持播放列表、频道或合集。请粘贴单个媒体项目。",
        errorLive: "不支持直播或即将开始的直播。", errorDRM: "无法下载受 DRM 保护的媒体。", errorRestricted: "不支持私密、付费或需要登录的媒体。",
        errorNoFormats: "没有找到可用的媒体格式。", errorNoVideo: "此项目没有可用的视频流。请选择 MP3。", errorNoAudio: "此项目没有可用的音频流。",
        errorMissingDependencies: "下载需要 yt-dlp 和 ffmpeg。", errorSetupBusy: "另一项 Homebrew 操作正在运行。请在其结束后重试。",
        errorSetupFailed: "无法安装下载工具。请检查 Homebrew 后重试。", errorTerminalPermission: "无法打开 Terminal。请在“系统设置”中允许 Terminal 自动化。",
        errorDownloadFailed: "媒体下载失败。请确认链接仍然公开且可用。", errorRemux: "所选流无法在不转码的情况下合并或重新封装为 MP4。请选择其他画质。",
        errorSubtitle: "无法下载并嵌入所选字幕。未发布不完整文件。", errorOptionalData: "无法嵌入所需封面、元数据或章节。未发布不完整文件。",
        errorLyrics: "无法将所选字幕添加为 MP3 歌词。未发布不完整文件。", errorFileSafety: "无法验证完成的文件或将它安全放入所选文件夹。"
    )

    static let zhTW = VideoDownloaderStrings(
        pageTitle: "影片下載器", hubDescription: "下載一個公開影片或 MP3，並選擇畫質與字幕", panelCaption: "將公開媒體連結儲存為 MP4 或 MP3",
        urlPlaceholder: "貼上公開的 HTTP 或 HTTPS 媒體網址",
        urlHelp: "網址只會在有效後開始檢查；不會儲存，也不會放入程序引數。", paste: "貼上", inspecting: "正在檢查媒體…", video: "影片", mp3: "MP3",
        quality: "影片畫質", best: "最佳", heightFormat: "%dp", qualityFallbackFormat: "%dp 無法使用，已改選 %dp。",
        subtitles: "字幕", none: "無", manual: "人工字幕", automatic: "自動字幕",
        destination: "下載檔案夾", choose: "選擇…", showInPanel: "在選單面板中顯示",
        settingsCaption: "下載會在私密暫存區處理，只有完成的 MP4 或 MP3 會放入所選檔案夾。", defaultLocation: "預設下載位置", resetDownloads: "重設為「下載項目」",
        embedThumbnail: "在 MP4 嵌入縮圖 / 在 MP3 嵌入封面", embedMetadata: "嵌入後設資料", embedChapters: "在 MP4 嵌入章節",
        embedSubtitle: "在 MP4 嵌入所選字幕", lyrics: "將所選字幕文字加入為 MP3 歌詞", dependencies: "下載工具",
        missingToolsFormat: "缺少：%@", installMissingTools: "安裝缺少的工具", setUpDownloader: "設定下載器",
        brewSetupNote: "Homebrew 只安裝缺少的 yt-dlp 與 ffmpeg。執行期間可以取消。",
        terminalSetupNote: "Terminal 會開啟官方 Homebrew 安裝，可能要求確認或密碼，接著安裝 yt-dlp 與 ffmpeg。",
        checkingTools: "正在檢查下載工具…", downloadVideo: "下載影片", downloadMP3: "下載 MP3", downloading: "正在下載",
        percentFormat: "%.0f%%", speedFormat: "%@/秒", etaFormat: "剩餘 %@", finalizing: "正在完成處理…", cancel: "取消", cancelling: "正在取消…",
        complete: "下載完成", downloadAnother: "下載另一個", revealFinder: "在 Finder 中顯示", retry: "重試", cancelled: "下載已取消",
        failureTitle: "無法完成下載", uploader: "上傳者", duration: "長度", thumbnail: "媒體縮圖",
        errorURLInvalid: "請輸入完整的公開 HTTP 或 HTTPS 媒體網址。", errorURLTooLong: "此網址太長，無法安全檢查。", errorURLControl: "網址含有換行或控制字元。",
        errorURLCredentials: "不支援含有使用者名稱或密碼的網址。", errorInspectionTimeout: "檢查時間過長。請檢查連結後重試。",
        errorInspectionFailed: "無法檢查媒體。請確認它公開且可用。", errorInspectionTooLarge: "網站傳回的資訊太多，無法安全處理。",
        errorInspectionMalformed: "yt-dlp 傳回的媒體資訊無法使用。", errorPlaylist: "不支援播放列表、頻道或合輯。請貼上一個媒體項目。",
        errorLive: "不支援直播或即將開始的直播。", errorDRM: "無法下載受 DRM 保護的媒體。", errorRestricted: "不支援私人、付費或需要登入的媒體。",
        errorNoFormats: "找不到可用的媒體格式。", errorNoVideo: "此項目沒有可用的影片串流。請選擇 MP3。", errorNoAudio: "此項目沒有可用的音訊串流。",
        errorMissingDependencies: "下載需要 yt-dlp 與 ffmpeg。", errorSetupBusy: "另一項 Homebrew 操作正在執行。請在完成後重試。",
        errorSetupFailed: "無法安裝下載工具。請檢查 Homebrew 後重試。", errorTerminalPermission: "無法開啟 Terminal。請在「系統設定」允許 Terminal 自動化。",
        errorDownloadFailed: "媒體下載失敗。請確認連結仍然公開且可用。", errorRemux: "所選串流無法在不轉碼的情況下合併或重新封裝為 MP4。請選擇其他畫質。",
        errorSubtitle: "無法下載並嵌入所選字幕。未發布不完整檔案。", errorOptionalData: "無法嵌入所需封面、後設資料或章節。未發布不完整檔案。",
        errorLyrics: "無法將所選字幕加入為 MP3 歌詞。未發布不完整檔案。", errorFileSafety: "無法驗證完成的檔案或安全地放入所選檔案夾。"
    )

    static let zhHK = VideoDownloaderStrings(
        pageTitle: "影片下載器", hubDescription: "下載一個公開影片或 MP3，並選擇畫質及字幕", panelCaption: "將公開媒體連結儲存為 MP4 或 MP3",
        urlPlaceholder: "貼上公開 HTTP 或 HTTPS 媒體網址",
        urlHelp: "網址只會在有效後開始檢查；不會儲存，也不會放入程序參數。", paste: "貼上", inspecting: "正在檢查媒體…", video: "影片", mp3: "MP3",
        quality: "影片畫質", best: "最佳", heightFormat: "%dp", qualityFallbackFormat: "%dp 無法使用，已改選 %dp。",
        subtitles: "字幕", none: "無", manual: "人工字幕", automatic: "自動字幕",
        destination: "下載資料夾", choose: "選擇…", showInPanel: "在選單面板顯示",
        settingsCaption: "下載會在私密暫存區處理，只有完成的 MP4 或 MP3 會放入所選資料夾。", defaultLocation: "預設下載位置", resetDownloads: "重設為「下載項目」",
        embedThumbnail: "在 MP4 嵌入縮圖 / 在 MP3 嵌入封面", embedMetadata: "嵌入詮釋資料", embedChapters: "在 MP4 嵌入章節",
        embedSubtitle: "在 MP4 嵌入所選字幕", lyrics: "將所選字幕文字加入為 MP3 歌詞", dependencies: "下載工具",
        missingToolsFormat: "欠缺：%@", installMissingTools: "安裝欠缺的工具", setUpDownloader: "設定下載器",
        brewSetupNote: "Homebrew 只會安裝欠缺的 yt-dlp 及 ffmpeg。執行期間可以取消。",
        terminalSetupNote: "Terminal 會開啟官方 Homebrew 安裝，可能要求確認或密碼，之後安裝 yt-dlp 及 ffmpeg。",
        checkingTools: "正在檢查下載工具…", downloadVideo: "下載影片", downloadMP3: "下載 MP3", downloading: "正在下載",
        percentFormat: "%.0f%%", speedFormat: "%@/秒", etaFormat: "尚餘 %@", finalizing: "正在完成處理…", cancel: "取消", cancelling: "正在取消…",
        complete: "下載完成", downloadAnother: "下載另一個", revealFinder: "在 Finder 顯示", retry: "再試", cancelled: "下載已取消",
        failureTitle: "無法完成下載", uploader: "上載者", duration: "長度", thumbnail: "媒體縮圖",
        errorURLInvalid: "請輸入完整的公開 HTTP 或 HTTPS 媒體網址。", errorURLTooLong: "此網址太長，無法安全檢查。", errorURLControl: "網址含有換行或控制字元。",
        errorURLCredentials: "不支援含有用戶名稱或密碼的網址。", errorInspectionTimeout: "檢查時間過長。請檢查連結後再試。",
        errorInspectionFailed: "無法檢查媒體。請確認它公開而且可用。", errorInspectionTooLarge: "網站傳回的資訊太多，無法安全處理。",
        errorInspectionMalformed: "yt-dlp 傳回的媒體資訊無法使用。", errorPlaylist: "不支援播放清單、頻道或合輯。請貼上一個媒體項目。",
        errorLive: "不支援直播或即將開始的直播。", errorDRM: "無法下載受 DRM 保護的媒體。", errorRestricted: "不支援私人、付費或需要登入的媒體。",
        errorNoFormats: "找不到可用的媒體格式。", errorNoVideo: "此項目沒有可用的影片串流。請選擇 MP3。", errorNoAudio: "此項目沒有可用的音訊串流。",
        errorMissingDependencies: "下載需要 yt-dlp 及 ffmpeg。", errorSetupBusy: "另一項 Homebrew 操作正在執行。請在完成後再試。",
        errorSetupFailed: "無法安裝下載工具。請檢查 Homebrew 後再試。", errorTerminalPermission: "無法開啟 Terminal。請在「系統設定」允許 Terminal 自動化。",
        errorDownloadFailed: "媒體下載失敗。請確認連結仍然公開而且可用。", errorRemux: "所選串流無法在不轉碼的情況下合併或重新封裝為 MP4。請選擇其他畫質。",
        errorSubtitle: "無法下載並嵌入所選字幕。未有發布不完整檔案。", errorOptionalData: "無法嵌入所需封面、詮釋資料或章節。未有發布不完整檔案。",
        errorLyrics: "無法將所選字幕加入為 MP3 歌詞。未有發布不完整檔案。", errorFileSafety: "無法驗證完成的檔案或安全放入所選資料夾。"
    )
}
