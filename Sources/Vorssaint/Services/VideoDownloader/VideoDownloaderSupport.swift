// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

enum VideoDownloaderOutputMode: String, CaseIterable, Identifiable {
    case video
    case mp3

    var id: String { rawValue }
    var expectedExtension: String { self == .video ? "mp4" : "mp3" }
}

enum VideoDownloaderQuality: Hashable, Identifiable {
    case best
    case height(Int)

    var id: String {
        switch self {
        case .best: return "best"
        case let .height(value): return "height-\(value)"
        }
    }
}

struct VideoDownloaderQualityFallback: Equatable {
    let requestedHeight: Int
    let actualHeight: Int

    static func detect(requested: VideoDownloaderQuality,
                       actualHeight: Int?) -> VideoDownloaderQualityFallback? {
        guard case let .height(requestedHeight) = requested,
              let actualHeight, actualHeight > 0, actualHeight < requestedHeight else { return nil }
        return VideoDownloaderQualityFallback(requestedHeight: requestedHeight,
                                              actualHeight: actualHeight)
    }
}

enum VideoDownloaderSubtitleSource: String, Hashable {
    case manual
    case automatic
}

struct VideoDownloaderSubtitleTrack: Hashable, Identifiable {
    let code: String
    let source: VideoDownloaderSubtitleSource
    let name: String?

    var id: String { "\(source.rawValue):\(code)" }
}

/// yt-dlp usually gives us codec details, but direct media URLs can leave those
/// fields blank even when the file is downloadable. Keep "unknown" separate
/// from "unavailable" so we do not block a download that can still work.
enum VideoDownloaderStreamAvailability: Equatable {
    case available
    case unavailable
    case unknown

    var canAttempt: Bool { self != .unavailable }
}

struct VideoDownloaderMedia: Equatable {
    let title: String
    let uploader: String?
    let duration: TimeInterval?
    let thumbnailURL: URL?
    let heights: [Int]
    let videoAvailability: VideoDownloaderStreamAvailability
    let audioAvailability: VideoDownloaderStreamAvailability
    let subtitles: [VideoDownloaderSubtitleTrack]
    let hasChapters: Bool

    var canAttemptVideo: Bool { videoAvailability.canAttempt }
    var canAttemptAudio: Bool { audioAvailability.canAttempt }
}

struct VideoDownloaderEmbeddingOptions: Equatable {
    let thumbnail: Bool
    let metadata: Bool
    let chapters: Bool
    let mp4Subtitle: Bool
    let mp3Lyrics: Bool
}

struct VideoDownloaderRequest {
    let source: ValidatedVideoURL
    let mode: VideoDownloaderOutputMode
    let quality: VideoDownloaderQuality
    let subtitle: VideoDownloaderSubtitleTrack?
    let destination: URL
    let media: VideoDownloaderMedia
    let options: VideoDownloaderEmbeddingOptions
}

struct VideoDownloaderProgress: Equatable {
    let fraction: Double?
    let speedBytesPerSecond: Double?
    let etaSeconds: TimeInterval?

    var isNetworkComplete: Bool { (fraction ?? 0) >= 1 }
}

/// Keep the stale-callback check shared by the workflow and its tests.
enum VideoDownloaderCallbackGate {
    static func accepts(_ callbackID: UUID, currentID: UUID?) -> Bool {
        guard let currentID else { return false }
        return callbackID == currentID
    }
}

enum VideoDownloaderFailure: Error, Equatable {
    case invalidURL(VideoURLValidationError)
    case inspectionTimedOut
    case inspectionFailed
    case inspectionTooLarge
    case malformedInspection
    case playlist
    case live
    case drm
    case restricted
    case noFormats
    case noVideo
    case noAudio
    case missingDependencies
    case downloadFailed
    case setupBusy
    case setupFailed
    case terminalPermission
    case mp4Remux
    case subtitle
    case optionalData
    case lyrics
    case fileSafety
    case cancelled
}

enum VideoURLValidationError: Error, Equatable {
    case empty
    case tooLong
    case controlCharacter
    case unsupportedScheme
    case missingHost
    case credentials
    case malformed
}

struct ValidatedVideoURL: Equatable {
    let value: URL
    let string: String
}

enum VideoDownloaderURLValidator {
    static let maximumUTF8Bytes = 16 * 1024

    static func validate(_ input: String) throws -> ValidatedVideoURL {
        guard input.utf8.count <= maximumUTF8Bytes else { throw VideoURLValidationError.tooLong }
        guard !input.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw VideoURLValidationError.controlCharacter
        }
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw VideoURLValidationError.empty }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else {
            throw VideoURLValidationError.malformed
        }
        guard scheme == "http" || scheme == "https" else {
            throw VideoURLValidationError.unsupportedScheme
        }
        guard let host = components.host, !host.isEmpty else {
            throw VideoURLValidationError.missingHost
        }
        guard components.user == nil, components.password == nil else {
            throw VideoURLValidationError.credentials
        }
        guard let url = components.url else { throw VideoURLValidationError.malformed }
        return ValidatedVideoURL(value: url, string: url.absoluteString)
    }
}

enum VideoDownloaderInspectionParser {
    static let maximumJSONBytes = 8 * 1024 * 1024

    static func parse(_ data: Data, maximumBytes: Int = maximumJSONBytes) throws -> VideoDownloaderMedia {
        guard data.count <= maximumBytes else { throw VideoDownloaderFailure.inspectionTooLarge }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VideoDownloaderFailure.malformedInspection
        }
        let type = string(json["_type"])?.lowercased()
        if type == "playlist" || type == "multi_video" || json["entries"] != nil {
            throw VideoDownloaderFailure.playlist
        }
        let liveStatus = string(json["live_status"])?.lowercased()
        if bool(json["is_live"]) == true
            || ["is_live", "is_upcoming", "post_live"].contains(liveStatus ?? "") {
            throw VideoDownloaderFailure.live
        }
        let availability = string(json["availability"])?.lowercased()
        if let availability,
           !["public", "unlisted"].contains(availability) {
            throw VideoDownloaderFailure.restricted
        }

        let formats = json["formats"] as? [[String: Any]] ?? []
        // DRM can apply to one format while another remains public. Reject the
        // item only when no usable public format is left. A top-level DRM flag
        // still wins when yt-dlp gives us no usable format details.
        let remoteFormats = formats.filter(isRemoteMediaFormat)
        let usableFormats = remoteFormats.filter { bool($0["has_drm"]) != true }
        if bool(json["has_drm"]) == true
            || (usableFormats.isEmpty && remoteFormats.contains(where: { bool($0["has_drm"]) == true })) {
            throw VideoDownloaderFailure.drm
        }
        guard !usableFormats.isEmpty else { throw VideoDownloaderFailure.noFormats }
        let videoFormats = usableFormats.filter { codecAvailability($0["vcodec"]) == .available }
        let videoAvailability = streamAvailability(in: usableFormats, codecKey: "vcodec")
        let audioAvailability = streamAvailability(in: usableFormats, codecKey: "acodec")
        guard let title = string(json["title"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            throw VideoDownloaderFailure.malformedInspection
        }

        let heights = Array(Set(videoFormats.compactMap { positiveInt($0["height"]) })).sorted(by: >)
        let subtitles = tracks(json["subtitles"], source: .manual)
            + tracks(json["automatic_captions"], source: .automatic)
        return VideoDownloaderMedia(
            title: title,
            uploader: string(json["uploader"]) ?? string(json["channel"]),
            duration: positiveDouble(json["duration"]),
            thumbnailURL: bestThumbnail(in: json),
            heights: heights,
            videoAvailability: videoAvailability,
            audioAvailability: audioAvailability,
            subtitles: subtitles,
            hasChapters: !(json["chapters"] as? [[String: Any]] ?? []).isEmpty
        )
    }

    private static func tracks(_ value: Any?,
                               source: VideoDownloaderSubtitleSource) -> [VideoDownloaderSubtitleTrack] {
        guard let values = value as? [String: Any] else { return [] }
        return values.compactMap { code, raw -> VideoDownloaderSubtitleTrack? in
            guard validSubtitleCode(code), code.lowercased() != "live_chat",
                  let entries = raw as? [[String: Any]], !entries.isEmpty else { return nil }
            let name = entries.compactMap { string($0["name"]) }.first
            return VideoDownloaderSubtitleTrack(code: code, source: source, name: name)
        }.sorted {
            if $0.code != $1.code { return $0.code.localizedStandardCompare($1.code) == .orderedAscending }
            return $0.source.rawValue < $1.source.rawValue
        }
    }

    static func validSubtitleCode(_ code: String) -> Bool {
        guard !code.isEmpty, code.utf8.count <= 64 else { return false }
        // yt-dlp treats --sub-langs as a regular expression. Allow ordinary
        // language codes only, so an inspected code stays an exact selector.
        return code.range(of: #"^[A-Za-z0-9][A-Za-z0-9_@-]*$"#,
                          options: .regularExpression) != nil
    }

    private static func isRemoteMediaFormat(_ format: [String: Any]) -> Bool {
        guard let rawURL = string(format["url"]),
              let components = URLComponents(string: rawURL),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host?.isEmpty == false else { return false }
        let protocolName = string(format["protocol"])?.lowercased() ?? ""
        return !["mhtml", "images", "storyboard"].contains(protocolName)
    }

    private static func streamAvailability(in formats: [[String: Any]],
                                           codecKey: String) -> VideoDownloaderStreamAvailability {
        let values = formats.map { codecAvailability($0[codecKey]) }
        if values.contains(.available) { return .available }
        if values.allSatisfy({ $0 == .unavailable }) { return .unavailable }
        return .unknown
    }

    private static func codecAvailability(_ value: Any?) -> VideoDownloaderStreamAvailability {
        guard let value = string(value)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !value.isEmpty else { return .unknown }
        return value == "none" ? .unavailable : .available
    }

    private struct ThumbnailCandidate {
        let url: URL
        let score: Double
    }

    private static func bestThumbnail(in json: [String: Any]) -> URL? {
        var candidates: [ThumbnailCandidate] = []
        if let value = remoteURL(string(json["thumbnail"])) {
            candidates.append(ThumbnailCandidate(url: value, score: 1))
        }
        for (index, item) in (json["thumbnails"] as? [[String: Any]] ?? []).enumerated() {
            guard let value = remoteURL(string(item["url"])) else { continue }
            let width = positiveDouble(item["width"]) ?? 0
            let height = positiveDouble(item["height"]) ?? 0
            let preference = double(item["preference"]) ?? 0
            candidates.append(ThumbnailCandidate(url: value,
                                                  score: width * height + preference * 1_000 + Double(index)))
        }
        return candidates.max(by: { $0.score < $1.score })?.url
    }

    private static func remoteURL(_ raw: String?) -> URL? {
        guard let raw, let parts = URLComponents(string: raw),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              parts.host?.isEmpty == false, parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }

    private static func string(_ value: Any?) -> String? { value as? String }
    private static func bool(_ value: Any?) -> Bool? { value as? Bool }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func positiveDouble(_ value: Any?) -> Double? {
        guard let value = double(value), value.isFinite, value > 0 else { return nil }
        return value
    }

    private static func positiveInt(_ value: Any?) -> Int? {
        guard let value = positiveDouble(value), value <= 16_384 else { return nil }
        return Int(value.rounded())
    }
}

enum VideoDownloaderSubtitleSelection {
    static func defaultTrack(in tracks: [VideoDownloaderSubtitleTrack],
                             appLanguage: AppLanguage) -> VideoDownloaderSubtitleTrack? {
        let exact = normalized(appLanguage.rawValue)
        let language = primary(exact)
        let priorities: [(VideoDownloaderSubtitleSource, (VideoDownloaderSubtitleTrack) -> Bool)] = [
            (.manual, { normalized($0.code) == exact }),
            (.manual, { primary($0.code) == language }),
            (.manual, { primary($0.code) == "en" }),
            (.automatic, { normalized($0.code) == exact }),
            (.automatic, { primary($0.code) == language }),
            (.automatic, { primary($0.code) == "en" }),
        ]
        for (source, matches) in priorities {
            if let track = tracks.first(where: { $0.source == source && matches($0) }) {
                return track
            }
        }
        return nil
    }

    static func localizedName(for track: VideoDownloaderSubtitleTrack,
                              appLanguage: AppLanguage) -> String {
        let locale = Locale(identifier: appLanguage.rawValue)
        let primaryCode = primary(track.code)
        return locale.localizedString(forLanguageCode: track.code)
            ?? locale.localizedString(forLanguageCode: primaryCode)
            ?? track.name
            ?? track.code
    }

    private static func primary(_ code: String) -> String {
        normalized(code).split(separator: "-").first.map(String.init) ?? normalized(code)
    }

    private static func normalized(_ code: String) -> String {
        code.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}

struct VideoDownloaderToolCommand: Equatable {
    let executable: String
    let arguments: [String]
}

enum VideoDownloaderCommandBuilder {
    static let progressPrefix = "__VORSSAINT_DOWNLOADER_PROGRESS__"
    static let titlePrefix = "__VORSSAINT_DOWNLOADER_TITLE__"
    static let qualityPrefix = "__VORSSAINT_DOWNLOADER_QUALITY__"
    static let pathPrefix = "__VORSSAINT_DOWNLOADER_PATH__"
    static let outputTemplate = "%(title).160B [%(id).40B].%(ext)s"
    // `!=?` means "not equal, or missing". Some extractors omit live_status;
    // a strict `!=` would filter out those otherwise normal videos.
    static let nonLiveMatchFilter = "!is_live & live_status!=?is_live & live_status!=?is_upcoming & live_status!=?post_live"

    static func inspection(ytDlpPath: String) -> VideoDownloaderToolCommand {
        VideoDownloaderToolCommand(executable: ytDlpPath, arguments: securityArguments + [
            // Keep the playlist wrapper so the parser can reject it. Inspect
            // only the first item to keep the work bounded; --max-downloads is
            // avoided because yt-dlp exits with 101 when it reaches the limit.
            "--yes-playlist", "--playlist-items", "1",
            "--skip-download", "--dump-single-json", "--no-check-formats",
            "--socket-timeout", "8", "--batch-file", "-",
        ])
    }

    static func dependencyProbe(tool: VideoDownloaderTool,
                                executablePath: String) -> VideoDownloaderToolCommand {
        switch tool {
        case .ytDlp:
            return VideoDownloaderToolCommand(executable: executablePath,
                                              arguments: ["--ignore-config", "--no-plugin-dirs", "--version"])
        case .ffmpeg:
            return VideoDownloaderToolCommand(executable: executablePath, arguments: ["-version"])
        }
    }

    static func download(ytDlpPath: String,
                         ffmpegPath: String,
                         staging: URL,
                         request: VideoDownloaderRequest) -> VideoDownloaderToolCommand {
        var arguments = securityArguments + [
            // The validated URL is the only input sent on stdin. These options
            // keep the request to one item without --max-downloads, which ends
            // with status 101 when it stops successfully.
            "--no-playlist", "--playlist-items", "1",
            "--match-filters", nonLiveMatchFilter,
            "--ffmpeg-location", ffmpegPath,
            "--newline", "--progress", "--progress-delta", "0.15",
            // yt-dlp writes missing template values as bare `NA`. That is fine
            // for a terminal, but not valid JSON, so send missing values as
            // `null` instead of losing the whole progress update.
            "--output-na-placeholder", "null",
            "--no-overwrites", "--no-post-overwrites", "--no-keep-video",
            "--no-write-info-json", "--no-write-playlist-metafiles",
            "--no-write-description", "--no-write-comments", "--no-embed-info-json",
            "--paths", staging.path, "--paths", "temp:\(staging.path)",
            "--output", outputTemplate,
            "--progress-template", "download:\(progressPrefix){\"downloaded\":%(progress.downloaded_bytes)j,\"total\":%(progress.total_bytes,total_bytes_estimate)j,\"percent\":%(progress._percent_str)j,\"speed\":%(progress.speed)j,\"eta\":%(progress.eta)j,\"elapsed\":%(progress.elapsed)j,\"fragment_index\":%(progress.fragment_index)j,\"fragment_count\":%(progress.fragment_count)j}",
            "--print", "before_dl:\(titlePrefix)%(title)j",
            "--print", "before_dl:\(qualityPrefix)%(height)j",
            "--print", "after_move:\(pathPrefix)%(filepath)j",
        ]

        switch request.mode {
        case .video:
            arguments += ["--format", videoFormatSelector(request.quality),
                          "--merge-output-format", "mp4", "--remux-video", "mp4"]
        case .mp3:
            arguments += ["--format", "ba/b", "--extract-audio", "--audio-format", "mp3",
                          "--audio-quality", "0"]
        }

        if request.options.thumbnail, request.media.thumbnailURL != nil {
            arguments += ["--write-thumbnail", "--convert-thumbnails", "jpg", "--embed-thumbnail"]
        } else {
            arguments += ["--no-write-thumbnail", "--no-embed-thumbnail"]
        }
        arguments.append(request.options.metadata ? "--embed-metadata" : "--no-embed-metadata")

        let embedsChapters = request.mode == .video && request.options.chapters && request.media.hasChapters
        arguments.append(embedsChapters ? "--embed-chapters" : "--no-embed-chapters")

        let wantsSubtitle = request.subtitle != nil && (
            (request.mode == .video && request.options.mp4Subtitle)
                || (request.mode == .mp3 && request.options.mp3Lyrics)
        )
        if wantsSubtitle, let subtitle = request.subtitle {
            switch subtitle.source {
            case .manual:
                arguments += ["--write-subs", "--no-write-auto-subs"]
            case .automatic:
                arguments += ["--no-write-subs", "--write-auto-subs"]
            }
            arguments += ["--sub-langs", subtitle.code, "--sub-format", "srt/vtt/best",
                          "--convert-subs", "srt"]
            if request.mode == .video {
                arguments += ["--embed-subs", "--compat-options", "no-keep-subs"]
            } else {
                arguments.append("--no-embed-subs")
            }
        } else {
            arguments += ["--no-write-subs", "--no-write-auto-subs", "--no-embed-subs"]
        }
        arguments += ["--batch-file", "-"]
        return VideoDownloaderToolCommand(executable: ytDlpPath, arguments: arguments)
    }

    static func videoFormatSelector(_ quality: VideoDownloaderQuality) -> String {
        switch quality {
        case .best: return "bv*+ba/b"
        case let .height(value):
            return "bv*[height<=\(max(1, value))]+ba/b[height<=\(max(1, value))]"
        }
    }

    static func ffmpegLyrics(ffmpegPath: String,
                             input: URL,
                             output: URL,
                             lyrics: String) -> VideoDownloaderToolCommand {
        VideoDownloaderToolCommand(executable: ffmpegPath, arguments: [
            "-nostdin", "-hide_banner", "-loglevel", "error", "-i", input.path,
            "-map", "0", "-map_metadata", "0", "-c", "copy", "-id3v2_version", "3",
            "-metadata", "lyrics=\(lyrics)", output.path,
        ])
    }

    static func homebrewInstall(brewPath: String,
                                missingTools: Set<VideoDownloaderTool>) -> VideoDownloaderToolCommand? {
        let formulae = VideoDownloaderTool.allCases.filter(missingTools.contains).map(\.formula)
        guard !formulae.isEmpty else { return nil }
        return VideoDownloaderToolCommand(executable: brewPath, arguments: ["install"] + formulae)
    }

    static let terminalSetupCommand = VideoDownloaderTerminalSetup.command()

    // Ignore local config and plugins here. A config file should not add
    // cookies, browser access, netrc settings, or commands to a download.
    private static let securityArguments = [
        "--ignore-config", "--no-config-locations", "--no-plugin-dirs", "--no-color",
        "--no-cookies", "--no-cookies-from-browser", "--no-exec",
    ]
}

/// Builds the fixed Terminal fallback used when Homebrew itself is missing.
/// Keeping it here makes the shell quoting easy to test, and no user URL or
/// destination is ever put into the command.
enum VideoDownloaderTerminalSetup {
    static let installerBodyProducer = "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    static let brewCandidatePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    static func command(installerBodyProducer: String = installerBodyProducer,
                        brewCandidatePaths: [String] = brewCandidatePaths,
                        statusFile: URL? = nil) -> String {
        let installer = #"/bin/bash -c "$(\#(installerBodyProducer))""#
        let branches = brewCandidatePaths.enumerated().map { index, path in
            let prefix = index == 0 ? "if" : "elif"
            let quoted = shellQuote(path)
            return "\(prefix) [ -x \(quoted) ]; then \(quoted) install yt-dlp ffmpeg;"
        }.joined(separator: " ")
        let transaction = "\(installer) && \(branches) else exit 1; fi"
        guard let statusFile else { return transaction }
        let status = shellQuote(statusFile.path)
        let temporary = shellQuote(statusFile.path + ".tmp")
        return "status=1; finish_vorssaint_setup() { /usr/bin/printf '%s\\n' \"$status\" > \(temporary) && /bin/mv -f \(temporary) \(status); }; trap 'status=$?; finish_vorssaint_setup' EXIT; trap 'exit 130' HUP INT TERM; \(transaction); status=$?; exit \"$status\""
    }

    static func statusFile(id: UUID = UUID(),
                           temporaryDirectory: URL = FileManager.default.temporaryDirectory) -> URL {
        temporaryDirectory.appendingPathComponent("vorssaint-video-setup-\(id.uuidString).status")
    }

    static func result(at statusFile: URL) -> Int32? {
        guard let data = try? Data(contentsOf: statusFile), data.count <= 32,
              let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let status = Int32(raw) else { return nil }
        return status
    }

    static func bootIdentifier() -> String {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0 {
            return "kernel:\(bootTime.tv_sec):\(bootTime.tv_usec)"
        }
        let estimatedBoot = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        return "estimated-minute:\(Int64(estimatedBoot / 60))"
    }

    private static func shellQuote(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_./-]+$"#, options: .regularExpression) != nil { return value }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum VideoDownloaderProtocolEvent: Equatable {
    case progress(VideoDownloaderProgress)
    case title(String)
    case selectedVideoHeight(Int?)
    case path(String)
}

enum VideoDownloaderProtocolParser {
    static func parse(line: String) -> VideoDownloaderProtocolEvent? {
        if line.hasPrefix(VideoDownloaderCommandBuilder.progressPrefix) {
            let payload = String(line.dropFirst(VideoDownloaderCommandBuilder.progressPrefix.count))
            guard let json = progressFields(payload) else { return nil }
            let downloaded = finite(json["downloaded"])
            let total = finite(json["total"])
            let percent = percentage(json["percent"])
            let elapsed = positive(json["elapsed"])
            let fraction: Double?
            if let percent {
                fraction = min(max(percent / 100, 0), 1)
            } else if let downloaded, let total, total > 0 {
                fraction = min(max(downloaded / total, 0), 1)
            } else if let fragmentIndex = finite(json["fragment_index"]),
                      let fragmentCount = positive(json["fragment_count"]) {
                fraction = min(max(fragmentIndex / fragmentCount, 0), 1)
            } else {
                fraction = nil
            }
            let speed = positive(json["speed"])
                ?? derivedSpeed(downloaded: downloaded, elapsed: elapsed)
            let eta = positive(json["eta"])
                ?? derivedETA(fraction: fraction, elapsed: elapsed)
            return .progress(VideoDownloaderProgress(
                fraction: fraction,
                speedBytesPerSecond: speed,
                etaSeconds: eta
            ))
        }
        if line.hasPrefix(VideoDownloaderCommandBuilder.titlePrefix) {
            return jsonString(String(line.dropFirst(VideoDownloaderCommandBuilder.titlePrefix.count))).map {
                .title($0)
            }
        }
        if line.hasPrefix(VideoDownloaderCommandBuilder.qualityPrefix) {
            let payload = String(line.dropFirst(VideoDownloaderCommandBuilder.qualityPrefix.count))
            guard let data = payload.data(using: .utf8),
                  let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
                return nil
            }
            if value is NSNull { return .selectedVideoHeight(nil) }
            guard let height = finite(value), height > 0, height <= Double(Int.max),
                  height.rounded(.towardZero) == height else { return nil }
            return .selectedVideoHeight(Int(height))
        }
        if line.hasPrefix(VideoDownloaderCommandBuilder.pathPrefix) {
            return jsonString(String(line.dropFirst(VideoDownloaderCommandBuilder.pathPrefix.count))).map {
                .path($0)
            }
        }
        return nil
    }

    /// yt-dlp usually uses `NA` for missing progress fields, and some versions
    /// can put a bad value next to otherwise useful ones. Read the known fields
    /// independently so one missing metric does not hide the rest.
    private static func progressFields(_ payload: String) -> [String: Any]? {
        if let data = payload.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{", trimmed.last == "}" else { return nil }
        let keys = ["downloaded", "total", "percent", "speed", "eta", "elapsed",
                    "fragment_index", "fragment_count"]
        var result: [String: Any] = [:]
        var recognizedField = false
        for key in keys {
            guard let raw = rawScalar(named: key, in: trimmed) else { continue }
            recognizedField = true
            guard let data = "[\(raw)]".data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let value = array.first else { continue }
            result[key] = value
        }
        return recognizedField ? result : nil
    }

    private static func rawScalar(named key: String, in object: String) -> Substring? {
        guard let keyRange = object.range(of: "\"\(key)\"") else { return nil }
        var cursor = keyRange.upperBound
        while cursor < object.endIndex, object[cursor].isWhitespace {
            cursor = object.index(after: cursor)
        }
        guard cursor < object.endIndex, object[cursor] == ":" else { return nil }
        cursor = object.index(after: cursor)
        while cursor < object.endIndex, object[cursor].isWhitespace {
            cursor = object.index(after: cursor)
        }
        let valueStart = cursor
        if cursor < object.endIndex, object[cursor] == "\"" {
            cursor = object.index(after: cursor)
            var escaped = false
            while cursor < object.endIndex {
                let character = object[cursor]
                cursor = object.index(after: cursor)
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    return object[valueStart..<cursor]
                }
            }
            return nil
        }
        while cursor < object.endIndex, object[cursor] != ",", object[cursor] != "}" {
            cursor = object.index(after: cursor)
        }
        let raw = object[valueStart..<cursor]
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : raw
    }

    private static func derivedSpeed(downloaded: Double?, elapsed: Double?) -> Double? {
        guard let downloaded, downloaded > 0, let elapsed, elapsed > 0 else { return nil }
        let value = downloaded / elapsed
        return value.isFinite && value > 0 ? value : nil
    }

    private static func derivedETA(fraction: Double?, elapsed: Double?) -> Double? {
        guard let fraction, fraction > 0, fraction < 1,
              let elapsed, elapsed > 0 else { return nil }
        let value = elapsed * (1 - fraction) / fraction
        return value.isFinite && value > 0 ? value : nil
    }

    private static func percentage(_ value: Any?) -> Double? {
        if let number = finite(value) { return number }
        guard var value = value as? String else { return nil }
        value = value.replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(value).flatMap { $0.isFinite ? $0 : nil }
    }

    private static func positive(_ value: Any?) -> Double? {
        guard let value = finite(value), value > 0 else { return nil }
        return value
    }

    private static func finite(_ value: Any?) -> Double? {
        let number: Double?
        if let value = value as? NSNumber { number = value.doubleValue }
        else if let value = value as? String { number = Double(value) }
        else { number = nil }
        guard let number, number.isFinite else { return nil }
        return number
    }

    private static func jsonString(_ value: String) -> String? {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data,
                                                               options: [.fragmentsAllowed]) as? String else { return nil }
        return decoded
    }
}

struct VideoDownloaderLineDecoder {
    private var buffer = Data()
    private let maximumBufferedBytes: Int

    init(maximumBufferedBytes: Int = 256 * 1024) {
        self.maximumBufferedBytes = maximumBufferedBytes
    }

    mutating func append(_ data: Data) -> [String] {
        buffer.append(data)
        if buffer.count > maximumBufferedBytes, !buffer.contains(0x0A) {
            buffer.removeFirst(buffer.count - maximumBufferedBytes)
        }
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            var line = buffer.prefix(upTo: newline)
            if line.last == 0x0D { line = line.dropLast() }
            lines.append(String(decoding: line, as: UTF8.self))
            buffer.removeSubrange(...newline)
        }
        return lines
    }

    mutating func finish() -> String? {
        guard !buffer.isEmpty else { return nil }
        var line = buffer[...]
        if line.last == 0x0D { line = line.dropLast() }
        buffer.removeAll(keepingCapacity: false)
        return String(decoding: line, as: UTF8.self)
    }
}

enum VideoDownloaderLyricsParser {
    static let maximumBytes = 64 * 1024

    static func parse(_ data: Data, maximumBytes: Int = maximumBytes) -> String {
        var text = String(decoding: data, as: UTF8.self)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var captions: [String] = []
        var block: [String] = []
        var skippingVTTBlock = false

        func flush() {
            let cleaned = block.map(cleanLine).filter { !$0.isEmpty }.joined(separator: "\n")
            block.removeAll(keepingCapacity: true)
            guard !cleaned.isEmpty, captions.last != cleaned else { return }
            captions.append(cleaned)
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if skippingVTTBlock {
                if line.isEmpty { skippingVTTBlock = false }
                continue
            }
            if line == "WEBVTT" || line.hasPrefix("WEBVTT ") { continue }
            if line == "STYLE" || line == "REGION" || line.hasPrefix("NOTE") {
                flush()
                skippingVTTBlock = true
                continue
            }
            if line.isEmpty {
                flush()
                continue
            }
            if line.range(of: #"^\d+$"#, options: .regularExpression) != nil, block.isEmpty { continue }
            if line.contains("-->") { flush(); continue }
            block.append(line)
        }
        flush()
        return utf8Prefix(captions.joined(separator: "\n\n"), maximumBytes: maximumBytes)
    }

    private static func cleanLine(_ line: String) -> String {
        let withoutTags = line.replacingOccurrences(of: #"<[^>]*>"#, with: "",
                                                     options: .regularExpression)
        return decodeEntities(withoutTags).trimmingCharacters(in: .whitespaces)
    }

    private static func decodeEntities(_ value: String) -> String {
        var result = value
        let ordinary = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                        "&apos;": "'", "&#39;": "'", "&nbsp;": " "]
        for (entity, replacement) in ordinary {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        let pattern = #"&#(x[0-9A-Fa-f]+|[0-9]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            guard let range = Range(match.range(at: 0), in: result),
                  let valueRange = Range(match.range(at: 1), in: result) else { continue }
            let token = String(result[valueRange])
            let scalarValue = token.lowercased().hasPrefix("x")
                ? UInt32(token.dropFirst(), radix: 16)
                : UInt32(token, radix: 10)
            guard let scalarValue, let scalar = UnicodeScalar(scalarValue) else { continue }
            result.replaceSubrange(range, with: String(Character(scalar)))
        }
        return result
    }

    private static func utf8Prefix(_ value: String, maximumBytes: Int) -> String {
        let data = Data(value.utf8)
        guard data.count > maximumBytes else { return value }
        var count = max(0, maximumBytes)
        while count > 0 {
            if let result = String(data: data.prefix(count), encoding: .utf8) { return result }
            count -= 1
        }
        return ""
    }
}

enum VideoDownloaderFileSupport {
    static let stagingPrefix = ".vorssaint-video-download-"
    static let ownerMarkerName = ".vorssaint-owner-pid"
    static let staleAge: TimeInterval = 24 * 60 * 60
    private static let ownerMarkerHeader = "vorssaint-video-download-v1"

    static func makeStagingDirectory(in destination: URL,
                                     id: UUID = UUID(),
                                     ownerPID: pid_t = getpid(),
                                     fileManager: FileManager = .default,
                                     writeOwnerMarker: ((URL) throws -> Void)? = nil) throws -> URL {
        let url = destination.appendingPathComponent(stagingPrefix + id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        do {
            if let writeOwnerMarker {
                try writeOwnerMarker(url.appendingPathComponent(ownerMarkerName))
            } else {
                try ownerMarkerData(id: id, pid: ownerPID)
                    .write(to: url.appendingPathComponent(ownerMarkerName), options: .atomic)
            }
        } catch {
            try? fileManager.removeItem(at: url)
            throw error
        }
        return url
    }

    static func withStagingDirectory<T>(in destination: URL,
                                        id: UUID = UUID(),
                                        fileManager: FileManager = .default,
                                        body: (URL) throws -> T) throws -> T {
        let staging = try makeStagingDirectory(in: destination, id: id, fileManager: fileManager)
        defer { try? fileManager.removeItem(at: staging) }
        return try body(staging)
    }

    static func isContained(_ candidate: URL, in staging: URL) -> Bool {
        let root = staging.standardizedFileURL.resolvingSymlinksInPath().path
        let value = candidate.standardizedFileURL.resolvingSymlinksInPath().path
        return value.hasPrefix(root + "/")
    }

    static func finalMedia(in staging: URL,
                           reportedPath: String,
                           mode: VideoDownloaderOutputMode,
                           fileManager: FileManager = .default) throws -> URL {
        let reported = URL(fileURLWithPath: reportedPath)
        guard isContained(reported, in: staging),
              reported.pathExtension.lowercased() == mode.expectedExtension else {
            throw VideoDownloaderFailure.fileSafety
        }
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(at: staging,
                                                      includingPropertiesForKeys: keys,
                                                      options: [.skipsHiddenFiles]) else {
            throw VideoDownloaderFailure.fileSafety
        }
        var media: [URL] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == mode.expectedExtension {
            guard isContained(url, in: staging),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { continue }
            media.append(url)
        }
        guard media.count == 1,
              media[0].standardizedFileURL.resolvingSymlinksInPath()
                == reported.standardizedFileURL.resolvingSymlinksInPath() else {
            throw VideoDownloaderFailure.fileSafety
        }
        return reported
    }

    static func collisionSafeURL(for fileName: String,
                                 in destination: URL,
                                 fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)) -> URL {
        let source = URL(fileURLWithPath: fileName)
        let ext = source.pathExtension
        let base = source.deletingPathExtension().lastPathComponent
        var candidate = destination.appendingPathComponent(source.lastPathComponent)
        var index = 2
        while fileExists(candidate.path) {
            let suffix = "\(base) (\(index))" + (ext.isEmpty ? "" : ".\(ext)")
            candidate = destination.appendingPathComponent(suffix)
            index += 1
        }
        return candidate
    }

    static func publish(_ staged: URL,
                        into destination: URL,
                        fileManager: FileManager = .default) throws -> URL {
        var attempt = 0
        while attempt < 10_000 {
            let target = collisionSafeURL(for: staged.lastPathComponent,
                                          in: destination,
                                          fileExists: fileManager.fileExists(atPath:))
            do {
                try fileManager.moveItem(at: staged, to: target)
                return target
            } catch CocoaError.fileWriteFileExists {
                attempt += 1
            }
        }
        throw VideoDownloaderFailure.fileSafety
    }

    static func cleanupStaleDirectories(in destination: URL,
                                        now: Date = Date(),
                                        fileManager: FileManager = .default) {
        guard let values = try? fileManager.contentsOfDirectory(at: destination,
                                                                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                                                                options: [.skipsSubdirectoryDescendants]) else { return }
        for url in values where url.lastPathComponent.hasPrefix(stagingPrefix) {
            guard let info = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey]),
                  info.isDirectory == true,
                  let date = info.contentModificationDate,
                  now.timeIntervalSince(date) >= staleAge,
                  let directoryID = stagingDirectoryID(url),
                  let markerData = try? Data(contentsOf: url.appendingPathComponent(ownerMarkerName)),
                  let ownerPID = ownerPID(from: markerData, expectedID: directoryID) else { continue }
            if VideoDownloaderProcessTree.isAlive(ownerPID) {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }

    static func ownerMarkerData(id: UUID, pid: pid_t) -> Data {
        Data("\(ownerMarkerHeader)\n\(id.uuidString)\n\(pid)\n".utf8)
    }

    private static func stagingDirectoryID(_ url: URL) -> UUID? {
        let name = url.lastPathComponent
        guard name.hasPrefix(stagingPrefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(stagingPrefix.count)))
    }

    private static func ownerPID(from data: Data, expectedID: UUID) -> pid_t? {
        guard data.count <= 512, let value = String(data: data, encoding: .utf8) else { return nil }
        let lines = value.split(whereSeparator: { $0.isNewline }).map(String.init)
        guard lines.count == 3, lines[0] == ownerMarkerHeader,
              UUID(uuidString: lines[1]) == expectedID,
              let pid = pid_t(lines[2]), pid > 0 else { return nil }
        return pid
    }
}

enum VideoDownloaderDestinationSupport {
    static func resolved(savedPath: String?,
                         downloads: URL,
                         isUsableDirectory: (URL) -> Bool) -> URL {
        if let savedPath, !savedPath.isEmpty {
            let saved = URL(fileURLWithPath: savedPath, isDirectory: true)
            if isUsableDirectory(saved) { return saved }
        }
        return downloads
    }

    static func resolved(savedPath: String?, fileManager: FileManager = .default) -> URL {
        let fallback = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        if !fileManager.fileExists(atPath: fallback.path) {
            try? fileManager.createDirectory(at: fallback, withIntermediateDirectories: true)
        }
        return resolved(savedPath: savedPath, downloads: fallback) { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
                && isDirectory.boolValue && fileManager.isWritableFile(atPath: url.path)
        }
    }
}

enum VideoDownloaderTool: String, CaseIterable, Hashable {
    case ytDlp
    case ffmpeg

    var executableName: String { self == .ytDlp ? "yt-dlp" : "ffmpeg" }
    var formula: String { executableName }
}

struct VideoDownloaderDependencies: Equatable {
    var paths: [VideoDownloaderTool: String]

    var missing: Set<VideoDownloaderTool> {
        Set(VideoDownloaderTool.allCases.filter { paths[$0] == nil })
    }

    var isReady: Bool { missing.isEmpty }
}

enum VideoDownloaderDependencySupport {
    static func candidatePaths(for tool: VideoDownloaderTool,
                               home: URL,
                               pathEnvironment: String?) -> [String] {
        let fixed = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin",
                     home.appendingPathComponent(".local/bin").path]
        let pathDirectories = (pathEnvironment ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (fixed + pathDirectories).compactMap { directory in
            let path = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent(tool.executableName).path
            return seen.insert(path).inserted ? path : nil
        }
    }

    static func brewPath(fileManager: FileManager = .default) -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first {
            fileManager.isExecutableFile(atPath: $0)
        }
    }
}

enum VideoDownloaderProcessTree {
    static func descendants(of root: pid_t) -> [pid_t] {
        var visited = Set<pid_t>()
        var result: [pid_t] = []
        func visit(_ parent: pid_t) {
            for child in children(of: parent) where child > 0 && visited.insert(child).inserted {
                visit(child)
                result.append(child)
            }
        }
        visit(root)
        return result
    }

    static func snapshot(of root: pid_t) -> [pid_t] {
        guard root > 0 else { return [] }
        return descendants(of: root) + [root]
    }

    static func terminate(_ root: pid_t,
                          initiallyTracked: [pid_t]? = nil,
                          grace: TimeInterval = 1.2) {
        guard root > 0 else { return }
        var tracked = Set((initiallyTracked ?? snapshot(of: root)).filter { $0 > 0 })
        tracked.insert(root)

        func discoverAndTerminateNewDescendants() {
            let parents = tracked.filter(isAlive)
            var discovered: [pid_t] = []
            for parent in parents {
                for descendant in descendants(of: parent)
                    where descendant > 0 && tracked.insert(descendant).inserted {
                    discovered.append(descendant)
                }
            }
            for pid in discovered where isAlive(pid) { _ = Darwin.kill(pid, SIGTERM) }
        }

        for pid in tracked where isAlive(pid) { _ = Darwin.kill(pid, SIGTERM) }
        let deadline = Date().addingTimeInterval(grace)
        while Date() < deadline, tracked.contains(where: isAlive) {
            discoverAndTerminateNewDescendants()
            usleep(20_000)
        }
        discoverAndTerminateNewDescendants()
        for pid in tracked where isAlive(pid) { _ = Darwin.kill(pid, SIGKILL) }
        let killDeadline = Date().addingTimeInterval(0.4)
        while Date() < killDeadline, tracked.contains(where: isAlive) { usleep(10_000) }
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        if Darwin.kill(pid, 0) == 0 {
            var info = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
               Int32(info.pbi_status) == SZOMB {
                return false
            }
            return true
        }
        return errno == EPERM
    }

    private static func children(of pid: pid_t) -> [pid_t] {
        let needed = proc_listchildpids(pid, nil, 0)
        guard needed > 0 else { return [] }
        var values = [pid_t](repeating: 0, count: Int(needed))
        let count = values.withUnsafeMutableBytes { buffer in
            proc_listchildpids(pid, buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return [] }
        return Array(values.prefix(Int(count))).filter { $0 > 0 }
    }
}
