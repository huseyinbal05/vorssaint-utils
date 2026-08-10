// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

enum VideoDownloaderPhase: Equatable {
    case idle
    case inspecting
    case ready
    case settingUp
    case downloading
    case finalizing
    case cancelling
    case completed
    case failed
    case cancelled

    var locksRequest: Bool {
        switch self {
        case .settingUp, .downloading, .finalizing, .cancelling: return true
        default: return false
        }
    }
}

enum VideoDownloaderDependencyState: Equatable {
    case probing(previous: VideoDownloaderDependencies?)
    case resolved(VideoDownloaderDependencies)

    var value: VideoDownloaderDependencies? {
        switch self {
        case let .probing(previous): return previous
        case let .resolved(value): return value
        }
    }

    var isProbing: Bool {
        if case .probing = self { return true }
        return false
    }
}

final class VideoDownloaderWorkflow: ObservableObject {
    static let shared = VideoDownloaderWorkflow()

    @Published private(set) var phase: VideoDownloaderPhase = .idle
    @Published private(set) var sourceText = ""
    @Published private(set) var media: VideoDownloaderMedia?
    @Published var mode: VideoDownloaderOutputMode = .video
    @Published var quality: VideoDownloaderQuality = .best
    @Published var subtitle: VideoDownloaderSubtitleTrack?
    @Published var subtitlesEnabled = false
    @Published private(set) var destination: URL
    @Published private(set) var dependencyState: VideoDownloaderDependencyState = .probing(previous: nil)
    @Published private(set) var progress = VideoDownloaderProgress(fraction: nil,
                                                                    speedBytesPerSecond: nil,
                                                                    etaSeconds: nil)
    @Published private(set) var activeTitle: String?
    @Published private(set) var qualityFallback: VideoDownloaderQualityFallback?
    @Published private(set) var completedFile: URL?
    @Published private(set) var failure: VideoDownloaderFailure?
    @Published private(set) var validationError: VideoURLValidationError?

    private let service: VideoDownloaderProcessServicing
    private let mutationGate: HomebrewMutationGate
    private let brewPathProvider: () -> String?
    private let terminalInstallerOpener: (URL) -> Bool
    private let featureAvailability: () -> Bool
    private var inspectionID = UUID()
    private var dependencyProbeID = UUID()
    private var operationID: UUID?
    private var debounce: DispatchWorkItem?
    private var terminalPolling: DispatchWorkItem?
    private var terminalReservation: HomebrewMutationGate.Reservation?
    private var terminalStatusFile: URL?
    private var pendingValidatedSource: ValidatedVideoURL?

    init(service: VideoDownloaderProcessServicing = VideoDownloaderProcessService.shared,
         mutationGate: HomebrewMutationGate = .shared,
         brewPathProvider: @escaping () -> String? = { VideoDownloaderDependencySupport.brewPath() },
         terminalInstallerOpener: @escaping (URL) -> Bool = { statusFile in
             HomebrewManager.shared.openVideoDownloaderInstaller(statusFile: statusFile)
         },
         featureAvailability: @escaping () -> Bool = { AppFeature.videoDownloader.isAvailable },
         automaticallyProbe: Bool = true) {
        self.service = service
        self.mutationGate = mutationGate
        self.brewPathProvider = brewPathProvider
        self.terminalInstallerOpener = terminalInstallerOpener
        self.featureAvailability = featureAvailability
        let saved = UserDefaults.standard.string(forKey: DefaultsKey.videoDownloaderDestinationPath)
        destination = VideoDownloaderDestinationSupport.resolved(savedPath: saved)
        VideoDownloaderFileSupport.cleanupStaleDirectories(in: destination)
        restoreTerminalSetupTracking()
        if automaticallyProbe { refreshDependencies(force: false) }
    }

    var canDownload: Bool {
        guard phase == .ready, dependencyState.value?.isReady == true,
              let media, !sourceText.isEmpty else { return false }
        switch mode {
        case .video: return media.canAttemptVideo && media.canAttemptAudio
        case .mp3: return media.canAttemptAudio
        }
    }

    var missingTools: Set<VideoDownloaderTool> {
        dependencyState.isProbing && dependencyState.value == nil
            ? [] : (dependencyState.value?.missing ?? [])
    }
    var isProbingDependencies: Bool { dependencyState.isProbing }
    var canSetupDependencies: Bool {
        !dependencyState.isProbing && !missingTools.isEmpty && !phase.locksRequest && phase != .inspecting
    }
    var canCancelSetup: Bool { phase == .settingUp && operationID != nil }

    func setSourceText(_ value: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !phase.locksRequest else { return }
        sourceText = value
        debounce?.cancel()
        debounce = nil
        inspectionID = UUID()
        service.cancelInspection(wait: false)
        media = nil
        subtitle = nil
        subtitlesEnabled = false
        quality = .best
        progress = VideoDownloaderProgress(fraction: nil, speedBytesPerSecond: nil, etaSeconds: nil)
        completedFile = nil
        activeTitle = nil
        qualityFallback = nil
        failure = nil
        pendingValidatedSource = nil
        do {
            let source = try VideoDownloaderURLValidator.validate(value)
            validationError = nil
            pendingValidatedSource = source
            phase = .idle
            let generation = inspectionID
            let item = DispatchWorkItem { [weak self] in
                self?.beginInspection(source, id: generation)
            }
            debounce = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        } catch let error as VideoURLValidationError {
            validationError = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : error
            phase = .idle
        } catch {
            validationError = .malformed
            phase = .idle
        }
    }

    func pasteURL() {
        GeneralPasteboardAccess.shared.async { [weak self] in
            let value = NSPasteboard.general.string(forType: .string) ?? ""
            DispatchQueue.main.async { self?.setSourceText(value) }
        }
    }

    func startDownload() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard canDownload, let media, let source = pendingValidatedSource else { return }
        if mode == .video, !media.canAttemptVideo {
            fail(.noVideo)
            return
        }
        if !media.canAttemptAudio {
            fail(.noAudio)
            return
        }
        let defaults = UserDefaults.standard
        let currentDestination = VideoDownloaderDestinationSupport.resolved(
            savedPath: defaults.string(forKey: DefaultsKey.videoDownloaderDestinationPath))
        destination = currentDestination
        let snapshot = VideoDownloaderEmbeddingOptions(
            thumbnail: defaults.bool(forKey: DefaultsKey.videoDownloaderEmbedThumbnail),
            metadata: defaults.bool(forKey: DefaultsKey.videoDownloaderEmbedMetadata),
            chapters: defaults.bool(forKey: DefaultsKey.videoDownloaderEmbedChapters),
            mp4Subtitle: defaults.bool(forKey: DefaultsKey.videoDownloaderEmbedSubtitle),
            mp3Lyrics: defaults.bool(forKey: DefaultsKey.videoDownloaderLyrics)
        )
        let id = UUID()
        operationID = id
        failure = nil
        completedFile = nil
        activeTitle = media.title
        qualityFallback = nil
        progress = VideoDownloaderProgress(fraction: nil, speedBytesPerSecond: nil, etaSeconds: nil)
        phase = .downloading
        let request = VideoDownloaderRequest(source: source,
                                             mode: mode,
                                             quality: quality,
                                             subtitle: subtitlesEnabled ? subtitle : nil,
                                             destination: currentDestination,
                                             media: media,
                                             options: snapshot)
        service.download(request, id: id, progress: { [weak self] callbackID, event in
            guard let self,
                  VideoDownloaderCallbackGate.accepts(callbackID, currentID: self.operationID) else { return }
            switch event {
            case let .progress(value):
                self.progress = value
                self.phase = value.isNetworkComplete ? .finalizing : .downloading
            case let .title(title):
                self.activeTitle = title
            case let .selectedVideoHeight(actualHeight):
                self.qualityFallback = VideoDownloaderQualityFallback.detect(
                    requested: request.quality,
                    actualHeight: actualHeight
                )
            case .path:
                break
            }
        }, completion: { [weak self] callbackID, result in
            guard let self,
                  VideoDownloaderCallbackGate.accepts(callbackID, currentID: self.operationID) else { return }
            self.operationID = nil
            switch result {
            case let .success(url):
                self.completedFile = url
                self.progress = VideoDownloaderProgress(fraction: 1,
                                                        speedBytesPerSecond: nil,
                                                        etaSeconds: nil)
                self.phase = .completed
            case let .failure(error):
                if error == .cancelled {
                    self.phase = .cancelled
                    self.failure = nil
                } else {
                    self.fail(error)
                }
            }
        })
    }

    func cancelActiveOperation() {
        dispatchPrecondition(condition: .onQueue(.main))
        switch phase {
        case .downloading, .finalizing, .cancelling:
            phase = .cancelling
            service.cancelDownload(wait: false)
        case .settingUp:
            // Direct setup has its own completion, which arrives only after the
            // process tree and pipe readers are done. Keep showing Cancelling
            // until then.
            guard operationID != nil else { return }
            phase = .cancelling
            service.cancelSetup(wait: false)
        default:
            break
        }
    }

    func retry() {
        dispatchPrecondition(condition: .onQueue(.main))
        if let failure, [.setupBusy, .setupFailed, .terminalPermission, .missingDependencies].contains(failure),
           !missingTools.isEmpty {
            self.failure = nil
            phase = .idle
            setupDependencies()
            return
        }
        failure = nil
        if media != nil, dependencyState.value?.isReady == true {
            phase = .ready
            startDownload()
        } else if let source = pendingValidatedSource {
            phase = .idle
            beginInspection(source, id: inspectionID)
        } else {
            phase = .idle
        }
    }

    func downloadAnother() {
        dispatchPrecondition(condition: .onQueue(.main))
        operationID = nil
        sourceText = ""
        media = nil
        subtitle = nil
        subtitlesEnabled = false
        quality = .best
        completedFile = nil
        activeTitle = nil
        qualityFallback = nil
        failure = nil
        validationError = nil
        pendingValidatedSource = nil
        phase = .idle
    }

    func revealCompletedFile() {
        guard let completedFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([completedFile])
    }

    func setDestination(_ url: URL) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !phase.locksRequest else { return }
        let resolved = VideoDownloaderDestinationSupport.resolved(savedPath: url.path)
        destination = resolved
        UserDefaults.standard.set(resolved.path, forKey: DefaultsKey.videoDownloaderDestinationPath)
        VideoDownloaderFileSupport.cleanupStaleDirectories(in: resolved)
    }

    func resetDestination() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !phase.locksRequest else { return }
        UserDefaults.standard.removeObject(forKey: DefaultsKey.videoDownloaderDestinationPath)
        destination = VideoDownloaderDestinationSupport.resolved(savedPath: nil)
    }

    func setupDependencies() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard canSetupDependencies else { return }
        let missing = missingTools
        failure = nil
        phase = .settingUp
        if let brew = brewPathProvider() {
            let id = UUID()
            operationID = id
            service.installMissingTools(brewPath: brew, missing: missing, id: id) {
                [weak self] callbackID, result in
                guard let self,
                      VideoDownloaderCallbackGate.accepts(callbackID, currentID: self.operationID) else { return }
                self.operationID = nil
                switch result {
                case .success:
                    self.beginDependencyProbe(force: true, context: .directSetup)
                case let .failure(error):
                    if error == .cancelled {
                        self.phase = .cancelled
                    } else {
                        self.fail(error)
                    }
                }
            }
        } else {
            guard let reservation = mutationGate.reserve() else {
                fail(.setupBusy)
                return
            }
            terminalReservation = reservation
            let statusFile = VideoDownloaderTerminalSetup.statusFile()
            try? FileManager.default.removeItem(at: statusFile)
            terminalStatusFile = statusFile
            UserDefaults.standard.set(statusFile.path,
                                      forKey: DefaultsKey.videoDownloaderTerminalSetupStatusPath)
            UserDefaults.standard.set(VideoDownloaderTerminalSetup.bootIdentifier(),
                                      forKey: DefaultsKey.videoDownloaderTerminalSetupBootID)
            let opened = terminalInstallerOpener(statusFile)
            guard opened else {
                clearTerminalSetupTracking(removeStatusFile: true, releaseReservation: true)
                fail(.terminalPermission)
                return
            }
            UserDefaults.standard.set(true, forKey: DefaultsKey.videoDownloaderTerminalSetupUsed)
            scheduleTerminalProbe()
        }
    }

    func refreshDependencies(force: Bool,
                             retryInspection: Bool = false) {
        beginDependencyProbe(force: force, context: .refresh(retryInspection: retryInspection))
    }

    func applicationBecameActive() {
        refreshDependencies(force: true, retryInspection: allowsAutomaticInspection)
    }

    func syncWithFeature() {
        if featureAvailability() {
            destination = VideoDownloaderDestinationSupport.resolved(
                savedPath: UserDefaults.standard.string(forKey: DefaultsKey.videoDownloaderDestinationPath))
            VideoDownloaderFileSupport.cleanupStaleDirectories(in: destination)
            if terminalStatusFile != nil {
                phase = .settingUp
                scheduleTerminalProbe()
            }
            refreshDependencies(force: true, retryInspection: allowsAutomaticInspection)
        } else {
            debounce?.cancel()
            terminalPolling?.cancel()
            inspectionID = UUID()
            dependencyProbeID = UUID()
            service.cancelAll(wait: true)
            operationID = nil
            phase = .cancelled
            if terminalStatusFile != nil { scheduleTerminalProbe() }
        }
    }

    func terminateAndWait() {
        debounce?.cancel()
        terminalPolling?.cancel()
        inspectionID = UUID()
        dependencyProbeID = UUID()
        releaseTerminalReservation()
        service.cancelAll(wait: true)
    }

    private func beginInspection(_ source: ValidatedVideoURL, id: UUID) {
        guard VideoDownloaderCallbackGate.accepts(id, currentID: inspectionID),
              featureAvailability(),
              [.idle, .inspecting, .ready].contains(phase),
              !phase.locksRequest else { return }
        guard dependencyState.value?.paths[.ytDlp] != nil else {
            phase = .idle
            return
        }
        phase = .inspecting
        validationError = nil
        failure = nil
        service.inspect(source, id: id) { [weak self] callbackID, result in
            guard let self,
                  VideoDownloaderCallbackGate.accepts(callbackID, currentID: self.inspectionID),
                  self.pendingValidatedSource == source else { return }
            switch result {
            case let .success(media):
                self.media = media
                self.quality = .best
                self.subtitle = VideoDownloaderSubtitleSelection.defaultTrack(
                    in: media.subtitles,
                    appLanguage: L10n.shared.language
                )
                self.subtitlesEnabled = self.subtitle != nil
                self.phase = .ready
            case let .failure(error):
                guard error != .cancelled else { return }
                self.fail(error)
            }
        }
    }

    private func scheduleTerminalProbe() {
        terminalPolling?.cancel()
        guard let statusFile = terminalStatusFile else { return }
        guard terminalReservation != nil else {
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.terminalStatusFile == statusFile else { return }
                if VideoDownloaderTerminalSetup.result(at: statusFile) != nil,
                   !self.featureAvailability() {
                    self.clearTerminalSetupTracking(removeStatusFile: true, releaseReservation: false)
                } else if let reservation = self.mutationGate.reserve() {
                    self.terminalReservation = reservation
                    self.scheduleTerminalProbe()
                } else {
                    self.scheduleTerminalProbe()
                }
            }
            terminalPolling = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
            return
        }
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.terminalStatusFile == statusFile else { return }
            guard VideoDownloaderTerminalSetup.result(at: statusFile) != nil else {
                self.scheduleTerminalProbe()
                return
            }
            if self.phase == .settingUp, self.featureAvailability() {
                self.beginDependencyProbe(force: true, context: .terminalSetup)
            } else {
                self.clearTerminalSetupTracking(removeStatusFile: true, releaseReservation: true)
            }
        }
        terminalPolling = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    private func fail(_ error: VideoDownloaderFailure) {
        if phase == .settingUp { releaseTerminalReservation() }
        failure = error
        phase = .failed
    }

    private enum DependencyProbeContext {
        case refresh(retryInspection: Bool)
        case directSetup
        case terminalSetup
    }

    private func beginDependencyProbe(force: Bool, context: DependencyProbeContext) {
        let id = UUID()
        dependencyProbeID = id
        dependencyState = .probing(previous: dependencyState.value)
        service.probeDependencies(force: force) { [weak self] dependencies in
            guard let self,
                  VideoDownloaderCallbackGate.accepts(id, currentID: self.dependencyProbeID) else { return }
            self.dependencyState = .resolved(dependencies)
            switch context {
            case let .refresh(retryInspection):
                if self.phase == .settingUp, self.operationID == nil {
                    if let statusFile = self.terminalStatusFile {
                        if VideoDownloaderTerminalSetup.result(at: statusFile) != nil {
                            self.finishTerminalSetup(with: dependencies)
                        } else {
                            self.scheduleTerminalProbe()
                        }
                    } else if dependencies.isReady {
                        self.phase = .idle
                    } else {
                        self.fail(.setupFailed)
                    }
                }
                if self.featureAvailability(), self.allowsAutomaticInspection,
                   retryInspection || (dependencies.paths[.ytDlp] != nil && self.media == nil) {
                    if let source = self.pendingValidatedSource {
                        self.beginInspection(source, id: self.inspectionID)
                    }
                }
            case .directSetup:
                guard dependencies.isReady else { self.fail(.setupFailed); return }
                self.phase = .idle
                if let source = self.pendingValidatedSource {
                    self.beginInspection(source, id: self.inspectionID)
                }
            case .terminalSetup:
                guard self.phase == .settingUp else { return }
                self.finishTerminalSetup(with: dependencies)
            }
        }
    }

    private var allowsAutomaticInspection: Bool {
        featureAvailability() && media == nil && [.idle, .inspecting, .ready].contains(phase)
    }

    private func finishTerminalSetup(with dependencies: VideoDownloaderDependencies) {
        guard let statusFile = terminalStatusFile,
              let status = VideoDownloaderTerminalSetup.result(at: statusFile) else {
            scheduleTerminalProbe()
            return
        }
        clearTerminalSetupTracking(removeStatusFile: true, releaseReservation: true)
        guard status == 0, dependencies.isReady else { fail(.setupFailed); return }
        phase = .idle
        if let source = pendingValidatedSource {
            beginInspection(source, id: inspectionID)
        }
    }

    private func restoreTerminalSetupTracking() {
        let defaults = UserDefaults.standard
        let path = defaults.string(forKey: DefaultsKey.videoDownloaderTerminalSetupStatusPath) ?? ""
        guard !path.isEmpty else { return }
        let statusFile = URL(fileURLWithPath: path)
        let storedBootID = defaults.string(forKey: DefaultsKey.videoDownloaderTerminalSetupBootID) ?? ""
        let currentBootID = VideoDownloaderTerminalSetup.bootIdentifier()
        if !storedBootID.isEmpty, storedBootID != currentBootID {
            try? FileManager.default.removeItem(at: statusFile)
            defaults.removeObject(forKey: DefaultsKey.videoDownloaderTerminalSetupStatusPath)
            defaults.removeObject(forKey: DefaultsKey.videoDownloaderTerminalSetupBootID)
            return
        }
        if VideoDownloaderTerminalSetup.result(at: statusFile) != nil {
            try? FileManager.default.removeItem(at: statusFile)
            defaults.removeObject(forKey: DefaultsKey.videoDownloaderTerminalSetupStatusPath)
            defaults.removeObject(forKey: DefaultsKey.videoDownloaderTerminalSetupBootID)
            return
        }
        terminalStatusFile = statusFile
        terminalReservation = mutationGate.reserve()
        phase = featureAvailability() ? .settingUp : .cancelled
        scheduleTerminalProbe()
    }

    private func clearTerminalSetupTracking(removeStatusFile: Bool,
                                            releaseReservation: Bool) {
        terminalPolling?.cancel()
        terminalPolling = nil
        if removeStatusFile, let terminalStatusFile {
            try? FileManager.default.removeItem(at: terminalStatusFile)
        }
        terminalStatusFile = nil
        UserDefaults.standard.removeObject(forKey: DefaultsKey.videoDownloaderTerminalSetupStatusPath)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.videoDownloaderTerminalSetupBootID)
        if releaseReservation { releaseTerminalReservation() }
    }

    private func releaseTerminalReservation() {
        terminalReservation?.release()
        terminalReservation = nil
    }
}
