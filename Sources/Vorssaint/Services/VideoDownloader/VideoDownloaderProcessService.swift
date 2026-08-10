// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

protocol VideoDownloaderProcessServicing: AnyObject {
    func probeDependencies(force: Bool, completion: @escaping (VideoDownloaderDependencies) -> Void)
    func inspect(_ source: ValidatedVideoURL, id: UUID,
                 completion: @escaping VideoDownloaderProcessService.InspectionCompletion)
    func download(_ request: VideoDownloaderRequest, id: UUID,
                  progress: @escaping (UUID, VideoDownloaderProtocolEvent) -> Void,
                  completion: @escaping VideoDownloaderProcessService.DownloadCompletion)
    func installMissingTools(brewPath: String, missing: Set<VideoDownloaderTool>, id: UUID,
                             completion: @escaping VideoDownloaderProcessService.SetupCompletion)
    func cancelInspection(wait: Bool)
    func cancelDownload(wait: Bool)
    func cancelSetup(wait: Bool)
    func cancelAll(wait: Bool)
}

final class VideoDownloaderProcessService: VideoDownloaderProcessServicing {
    static let shared = VideoDownloaderProcessService()

    typealias InspectionCompletion = (UUID, Result<VideoDownloaderMedia, VideoDownloaderFailure>) -> Void
    typealias DownloadCompletion = (UUID, Result<URL, VideoDownloaderFailure>) -> Void
    typealias SetupCompletion = (UUID, Result<Void, VideoDownloaderFailure>) -> Void

    private let workQueue = DispatchQueue(label: "com.vorssaint.video-downloader", qos: .userInitiated)
    private let dependencyQueue = DispatchQueue(label: "com.vorssaint.video-downloader.dependencies",
                                                qos: .utility)
    private let operationLock = NSLock()
    private let dependencyCacheLock = NSLock()
    private let mutationGate: HomebrewMutationGate
    private var inspectionOperation: VideoDownloaderProcessOperation?
    private var downloadOperation: VideoDownloaderProcessOperation?
    private var setupOperation: VideoDownloaderProcessOperation?
    private var cachedToolPaths: [VideoDownloaderTool: String] = [:]

    init(initialToolPaths: [VideoDownloaderTool: String] = [:],
         mutationGate: HomebrewMutationGate = .shared) {
        cachedToolPaths = initialToolPaths
        self.mutationGate = mutationGate
    }

    func probeDependencies(force: Bool = false,
                           completion: @escaping (VideoDownloaderDependencies) -> Void) {
        dependencyQueue.async { [weak self] in
            guard let self else { return }
            // A forced refresh checks the tools again, but keeps the current
            // paths until both new probes have finished.
            let previousPaths = self.cachedPathsSnapshot()
            var paths: [VideoDownloaderTool: String] = [:]
            for tool in VideoDownloaderTool.allCases {
                let discovered = VideoDownloaderDependencySupport.candidatePaths(
                    for: tool,
                    home: FileManager.default.homeDirectoryForCurrentUser,
                    pathEnvironment: ProcessInfo.processInfo.environment["PATH"]
                )
                // Try the cached path first. It may be a valid local install
                // that is no longer on PATH, so force-refresh it too.
                let candidates = ([previousPaths[tool]].compactMap { $0 } + discovered)
                    .reduce(into: [String]()) { result, candidate in
                        if !result.contains(candidate) { result.append(candidate) }
                    }
                if let path = candidates.first(where: { candidate in
                    FileManager.default.isExecutableFile(atPath: candidate) && self.probe(tool, path: candidate)
                }) {
                    paths[tool] = path
                }
            }
            self.replaceCachedPaths(with: paths)
            DispatchQueue.main.async { completion(VideoDownloaderDependencies(paths: paths)) }
        }
    }

    func inspect(_ source: ValidatedVideoURL,
                 id: UUID,
                 completion: @escaping InspectionCompletion) {
        cancelInspection(wait: false)
        let operation = VideoDownloaderProcessOperation(id: id)
        setOperation(operation, kind: .inspection)
        workQueue.async { [weak self] in
            guard let self else { operation.finish(); return }
            let outcome: Result<VideoDownloaderMedia, VideoDownloaderFailure>
            if let ytDlp = self.cachedPath(for: .ytDlp) {
            let result = self.run(
                VideoDownloaderCommandBuilder.inspection(ytDlpPath: ytDlp),
                standardInput: Data((source.string + "\n").utf8),
                operation: operation,
                timeout: 20,
                stdoutLimit: VideoDownloaderInspectionParser.maximumJSONBytes + 1,
                stderrLimit: 128 * 1024
            )
            if operation.wasCancelled {
                outcome = .failure(.cancelled)
            } else if operation.timedOut {
                outcome = .failure(.inspectionTimedOut)
            } else if result.stdoutOverflow {
                outcome = .failure(.inspectionTooLarge)
            } else if result.status != 0 {
                outcome = .failure(.inspectionFailed)
            } else {
                do {
                    outcome = .success(try VideoDownloaderInspectionParser.parse(result.stdout))
                } catch let failure as VideoDownloaderFailure {
                    outcome = .failure(failure)
                } catch {
                    outcome = .failure(.malformedInspection)
                }
            }
            } else {
                outcome = .failure(.missingDependencies)
            }
            operation.finish()
            self.clearOperation(operation, kind: .inspection)
            self.completeInspection(id, outcome, completion)
        }
    }

    func download(_ request: VideoDownloaderRequest,
                  id: UUID,
                  progress: @escaping (UUID, VideoDownloaderProtocolEvent) -> Void,
                  completion: @escaping DownloadCompletion) {
        cancelInspection(wait: false)
        let operation = VideoDownloaderProcessOperation(id: id)
        operationLock.lock()
        let alreadyActive = downloadOperation != nil || setupOperation != nil
        if !alreadyActive { downloadOperation = operation }
        operationLock.unlock()
        guard !alreadyActive else {
            DispatchQueue.main.async { completion(id, .failure(.downloadFailed)) }
            return
        }
        workQueue.async { [weak self] in
            guard let self else { operation.finish(); return }
            let outcome = self.performDownload(request, id: id, operation: operation, progress: progress)
            operation.finish()
            self.clearOperation(operation, kind: .download)
            self.completeDownload(id, outcome, completion)
        }
    }

    private func performDownload(_ request: VideoDownloaderRequest,
                                 id: UUID,
                                 operation: VideoDownloaderProcessOperation,
                                 progress: @escaping (UUID, VideoDownloaderProtocolEvent) -> Void)
        -> Result<URL, VideoDownloaderFailure> {
        guard let ytDlp = cachedPath(for: .ytDlp),
              let ffmpeg = cachedPath(for: .ffmpeg) else {
            return .failure(.missingDependencies)
        }
        do {
            let published = try VideoDownloaderFileSupport.withStagingDirectory(in: request.destination, id: id) {
                created -> URL in
                let protocolCollector = VideoDownloaderProtocolCollector(id: id, progress: progress)
                let command = VideoDownloaderCommandBuilder.download(ytDlpPath: ytDlp,
                                                                      ffmpegPath: ffmpeg,
                                                                      staging: created,
                                                                      request: request)
                let result = self.run(
                    command,
                    standardInput: Data((request.source.string + "\n").utf8),
                    operation: operation,
                    timeout: nil,
                    stdoutLimit: 1024 * 1024,
                    stderrLimit: 256 * 1024,
                    currentDirectory: created
                ) { chunk in
                    protocolCollector.consume(chunk, from: .standardOutput)
                } onStderr: { chunk in
                    protocolCollector.consume(chunk, from: .standardError)
                }
                let reportedPath = protocolCollector.finish()
                if operation.wasCancelled { throw VideoDownloaderFailure.cancelled }
                guard result.status == 0 else { throw self.downloadFailure(result.stderr, request: request) }
                if let subtitleFailure = self.requestedSubtitleFailure(result.stderr, request: request) {
                    throw subtitleFailure
                }
                if self.requestedOptionalDataFailed(result.stderr, request: request) {
                    throw VideoDownloaderFailure.optionalData
                }
                guard let reportedPath else { throw VideoDownloaderFailure.fileSafety }
                var mediaFile = try VideoDownloaderFileSupport.finalMedia(in: created,
                                                                          reportedPath: reportedPath,
                                                                          mode: request.mode)
                if request.mode == .mp3, request.options.mp3Lyrics, request.subtitle != nil {
                    DispatchQueue.main.async {
                        progress(id, .progress(VideoDownloaderProgress(fraction: 1,
                                                                      speedBytesPerSecond: nil,
                                                                      etaSeconds: nil)))
                    }
                    mediaFile = try self.embedLyrics(in: mediaFile,
                                                     staging: created,
                                                     ffmpegPath: ffmpeg,
                                                     operation: operation)
                }
                if operation.wasCancelled { throw VideoDownloaderFailure.cancelled }
                let published = try VideoDownloaderFileSupport.publish(mediaFile,
                                                                        into: request.destination)
                return published
            }
            return .success(published)
        } catch let failure as VideoDownloaderFailure {
            return .failure(operation.wasCancelled ? .cancelled : failure)
        } catch {
            return .failure(operation.wasCancelled ? .cancelled : .fileSafety)
        }
    }

    func installMissingTools(brewPath: String,
                             missing: Set<VideoDownloaderTool>,
                             id: UUID,
                             completion: @escaping SetupCompletion) {
        guard let command = VideoDownloaderCommandBuilder.homebrewInstall(brewPath: brewPath,
                                                                          missingTools: missing),
              let reservation = mutationGate.reserve() else {
            DispatchQueue.main.async { completion(id, .failure(.setupBusy)) }
            return
        }
        let operation = VideoDownloaderProcessOperation(id: id)
        operationLock.lock()
        let alreadyActive = setupOperation != nil || downloadOperation != nil
        if !alreadyActive { setupOperation = operation }
        operationLock.unlock()
        guard !alreadyActive else {
            reservation.release()
            DispatchQueue.main.async { completion(id, .failure(.setupBusy)) }
            return
        }
        workQueue.async { [weak self] in
            guard let self else { reservation.release(); operation.finish(); return }
            let result = self.run(command,
                                  standardInput: nil,
                                  operation: operation,
                                  timeout: nil,
                                  stdoutLimit: 256 * 1024,
                                  stderrLimit: 256 * 1024)
            let outcome: Result<Void, VideoDownloaderFailure>
            if operation.wasCancelled { outcome = .failure(.cancelled) }
            else if result.status == 0 { outcome = .success(()) }
            else { outcome = .failure(.setupFailed) }
            reservation.release()
            operation.finish()
            self.clearOperation(operation, kind: .setup)
            DispatchQueue.main.async { completion(id, outcome) }
        }
    }

    func cancelInspection(wait: Bool) { cancel(kind: .inspection, wait: wait) }
    func cancelDownload(wait: Bool) { cancel(kind: .download, wait: wait) }
    func cancelSetup(wait: Bool) { cancel(kind: .setup, wait: wait) }

    func cancelAll(wait: Bool) {
        cancelInspection(wait: wait)
        cancelDownload(wait: wait)
        cancelSetup(wait: wait)
    }

    private func probe(_ tool: VideoDownloaderTool, path: String) -> Bool {
        let operation = VideoDownloaderProcessOperation(id: UUID())
        let result = run(VideoDownloaderCommandBuilder.dependencyProbe(tool: tool,
                                                                       executablePath: path),
                         standardInput: nil,
                         operation: operation,
                         timeout: 4,
                         stdoutLimit: 16 * 1024,
                         stderrLimit: 16 * 1024)
        operation.finish()
        return result.status == 0 && !operation.timedOut && !result.stdout.isEmpty
    }

    private func cachedPath(for tool: VideoDownloaderTool) -> String? {
        dependencyCacheLock.lock()
        defer { dependencyCacheLock.unlock() }
        return cachedToolPaths[tool]
    }

    private func cachedPathsSnapshot() -> [VideoDownloaderTool: String] {
        dependencyCacheLock.lock()
        defer { dependencyCacheLock.unlock() }
        return cachedToolPaths
    }

    private func replaceCachedPaths(with paths: [VideoDownloaderTool: String]) {
        dependencyCacheLock.lock()
        cachedToolPaths = paths
        dependencyCacheLock.unlock()
    }

    private func downloadFailure(_ errorData: Data,
                                 request: VideoDownloaderRequest) -> VideoDownloaderFailure {
        if let failure = requestedSubtitleFailure(errorData, request: request) { return failure }
        if requestedOptionalDataFailed(errorData, request: request) { return .optionalData }
        guard request.mode == .video else { return .downloadFailed }
        let message = String(decoding: errorData, as: UTF8.self).lowercased()
        let remuxSignals = ["conversion failed", "could not write header", "not supported in container",
                            "could not find tag for codec",
                            "muxer does not support", "error opening output", "mergeformats",
                            "videoremuxer", "ffmpeg video remuxer"]
        return remuxSignals.contains(where: message.contains) ? .mp4Remux : .downloadFailed
    }

    private func requestedSubtitleFailure(_ errorData: Data,
                                          request: VideoDownloaderRequest) -> VideoDownloaderFailure? {
        guard request.subtitle != nil else { return nil }
        let requested = (request.mode == .video && request.options.mp4Subtitle)
            || (request.mode == .mp3 && request.options.mp3Lyrics)
        guard requested else { return nil }
        let message = String(decoding: errorData, as: UTF8.self).lowercased()
        let unavailable = message.contains("requested subtitles not available")
            || message.contains("no subtitles for the requested languages")
            || message.contains("unable to download video subtitles")
            || message.contains("subtitle download failed")
            || (message.contains("subtitle") && failureLanguage(in: message))
        guard unavailable else { return nil }
        return request.mode == .video ? .subtitle : .lyrics
    }

    private func requestedOptionalDataFailed(_ errorData: Data,
                                             request: VideoDownloaderRequest) -> Bool {
        let message = String(decoding: errorData, as: UTF8.self).lowercased()
        if request.options.thumbnail, request.media.thumbnailURL != nil,
           ((message.contains("thumbnail") || message.contains("cover art"))
                && failureLanguage(in: message)) {
            return true
        }
        if request.options.metadata,
           message.contains("metadata"), failureLanguage(in: message) { return true }
        if request.mode == .video, request.options.chapters, request.media.hasChapters,
           message.contains("chapter"), failureLanguage(in: message) { return true }
        return false
    }

    private func failureLanguage(in message: String) -> Bool {
        ["error", "failed", "failure", "unable", "cannot", "could not", "not supported"]
            .contains(where: message.contains)
    }

    private func embedLyrics(in mediaFile: URL,
                             staging: URL,
                             ffmpegPath: String,
                             operation: VideoDownloaderProcessOperation) throws -> URL {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: staging,
                                                       includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                                                       options: [.skipsHiddenFiles]) else {
            throw VideoDownloaderFailure.lyrics
        }
        let subtitles = enumerator.compactMap { $0 as? URL }.filter {
            ["srt", "vtt"].contains($0.pathExtension.lowercased())
                && VideoDownloaderFileSupport.isContained($0, in: staging)
        }
        guard subtitles.count == 1,
              let size = try? subtitles[0].resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= 8 * 1024 * 1024,
              let data = try? Data(contentsOf: subtitles[0]) else {
            throw VideoDownloaderFailure.lyrics
        }
        let subtitle = subtitles[0]
        let temporary = staging.appendingPathComponent(".vorssaint-lyrics-\(UUID().uuidString).mp3")
        defer {
            try? fileManager.removeItem(at: subtitle)
            try? fileManager.removeItem(at: temporary)
        }
        let lyrics = VideoDownloaderLyricsParser.parse(data)
        guard !lyrics.isEmpty else { throw VideoDownloaderFailure.lyrics }
        let result = run(VideoDownloaderCommandBuilder.ffmpegLyrics(ffmpegPath: ffmpegPath,
                                                                    input: mediaFile,
                                                                    output: temporary,
                                                                    lyrics: lyrics),
                         standardInput: nil,
                         operation: operation,
                         timeout: nil,
                         stdoutLimit: 64 * 1024,
                         stderrLimit: 128 * 1024,
                         currentDirectory: staging)
        if operation.wasCancelled { throw VideoDownloaderFailure.cancelled }
        guard result.status == 0,
              VideoDownloaderFileSupport.isContained(temporary, in: staging),
              let outputSize = try? temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              outputSize > 0 else { throw VideoDownloaderFailure.lyrics }
        _ = try fileManager.replaceItemAt(mediaFile, withItemAt: temporary,
                                          backupItemName: nil, options: [])
        return mediaFile
    }

    private struct ProcessResult {
        let status: Int32
        let stdout: Data
        let stderr: Data
        let stdoutOverflow: Bool
        let stderrOverflow: Bool
    }

    private func run(_ command: VideoDownloaderToolCommand,
                     standardInput: Data?,
                     operation: VideoDownloaderProcessOperation,
                     timeout: TimeInterval?,
                     stdoutLimit: Int,
                     stderrLimit: Int,
                     currentDirectory: URL? = nil,
                     onStdout: ((Data) -> Void)? = nil,
                     onStderr: ((Data) -> Void)? = nil) -> ProcessResult {
        guard !operation.wasCancelled else {
            return ProcessResult(status: -1, stdout: Data(), stderr: Data(),
                                 stdoutOverflow: false, stderrOverflow: false)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.currentDirectoryURL = currentDirectory
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do {
            try process.run()
        } catch {
            try? inputPipe.fileHandleForWriting.close()
            try? outputPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForReading.close()
            return ProcessResult(status: -1, stdout: Data(), stderr: Data(),
                                 stdoutOverflow: false, stderrOverflow: false)
        }
        operation.attach(process)
        try? outputPipe.fileHandleForWriting.close()
        try? errorPipe.fileHandleForWriting.close()

        let readers = DispatchGroup()
        let readerStop = VideoDownloaderPipeDrainSignal()
        let stdoutBox = VideoDownloaderDataBox(limit: stdoutLimit)
        let stderrBox = VideoDownloaderDataBox(limit: stderrLimit)
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            Self.drain(outputPipe.fileHandleForReading, into: stdoutBox,
                       stop: readerStop, onChunk: onStdout)
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            Self.drain(errorPipe.fileHandleForReading, into: stderrBox,
                       stop: readerStop, onChunk: onStderr)
            readers.leave()
        }

        if let standardInput {
            try? inputPipe.fileHandleForWriting.write(contentsOf: standardInput)
        }
        try? inputPipe.fileHandleForWriting.close()

        if let timeout {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                operation.timeoutIfRunning(process)
            }
        }
        process.waitUntilExit()
        // The root process decides when the operation is over. A child can
        // inherit a pipe and stay around, so drain briefly and close the
        // readers instead of waiting forever.
        readerStop.requestStop()
        readers.wait()
        operation.detach(process)
        let stdout = stdoutBox.snapshot()
        let stderr = stderrBox.snapshot()
        return ProcessResult(status: process.terminationStatus,
                             stdout: stdout.data,
                             stderr: stderr.data,
                             stdoutOverflow: stdout.overflow,
                             stderrOverflow: stderr.overflow)
    }

    private static func drain(_ handle: FileHandle,
                              into box: VideoDownloaderDataBox,
                              stop: VideoDownloaderPipeDrainSignal,
                              onChunk: ((Data) -> Void)?) {
        defer { try? handle.close() }
        let descriptor = handle.fileDescriptor
        var buffer = [UInt8](repeating: 0, count: 32 * 1024)
        var stoppingDeadline: Date?
        while true {
            if stop.isRequested, stoppingDeadline == nil {
                stoppingDeadline = Date().addingTimeInterval(0.1)
            }
            if let stoppingDeadline, Date() >= stoppingDeadline { return }

            var state = pollfd(fd: descriptor,
                               events: Int16(POLLIN | POLLHUP | POLLERR),
                               revents: 0)
            let timeout: Int32 = stoppingDeadline == nil ? 50 : 0
            let readiness = Darwin.poll(&state, 1, timeout)
            if readiness == 0 {
                if stoppingDeadline != nil { return }
                continue
            }
            if readiness < 0 {
                if errno == EINTR { continue }
                return
            }
            if state.revents & Int16(POLLNVAL | POLLERR) != 0 { return }
            guard state.revents & Int16(POLLIN | POLLHUP) != 0 else { continue }

            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(descriptor, bytes.baseAddress, bytes.count)
            }
            if count == 0 { return }
            if count < 0 {
                if errno == EINTR { continue }
                return
            }
            let chunk = Data(buffer.prefix(count))
            box.append(chunk)
            onChunk?(chunk)
        }
    }

    private enum OperationKind { case inspection, download, setup }

    private func setOperation(_ operation: VideoDownloaderProcessOperation, kind: OperationKind) {
        operationLock.lock()
        defer { operationLock.unlock() }
        switch kind {
        case .inspection: inspectionOperation = operation
        case .download: downloadOperation = operation
        case .setup: setupOperation = operation
        }
    }

    private func clearOperation(_ operation: VideoDownloaderProcessOperation, kind: OperationKind) {
        operationLock.lock()
        defer { operationLock.unlock() }
        switch kind {
        case .inspection where inspectionOperation === operation: inspectionOperation = nil
        case .download where downloadOperation === operation: downloadOperation = nil
        case .setup where setupOperation === operation: setupOperation = nil
        default: break
        }
    }

    private func cancel(kind: OperationKind, wait: Bool) {
        operationLock.lock()
        let operation: VideoDownloaderProcessOperation?
        switch kind {
        case .inspection: operation = inspectionOperation
        case .download: operation = downloadOperation
        case .setup: operation = setupOperation
        }
        operationLock.unlock()
        operation?.cancel()
        if wait { operation?.wait() }
    }

    private func completeInspection(_ id: UUID,
                                    _ result: Result<VideoDownloaderMedia, VideoDownloaderFailure>,
                                    _ completion: @escaping InspectionCompletion) {
        DispatchQueue.main.async { completion(id, result) }
    }

    private func completeDownload(_ id: UUID,
                                  _ result: Result<URL, VideoDownloaderFailure>,
                                  _ completion: @escaping DownloadCompletion) {
        DispatchQueue.main.async { completion(id, result) }
    }
}

private enum VideoDownloaderProtocolStream {
    case standardOutput
    case standardError
}

/// yt-dlp can put progress on either stdout or stderr. Read both at once so a
/// full pipe cannot stall the process, then turn them into one stream of
/// progress events and the final output path.
private final class VideoDownloaderProtocolCollector {
    private let lock = NSLock()
    private let id: UUID
    private let progress: (UUID, VideoDownloaderProtocolEvent) -> Void
    private var standardOutputDecoder = VideoDownloaderLineDecoder()
    private var standardErrorDecoder = VideoDownloaderLineDecoder()
    private var reportedPath: String?
    private var lastProgressPublish = Date.distantPast
    private var lastPublishedProgress: VideoDownloaderProgress?

    init(id: UUID, progress: @escaping (UUID, VideoDownloaderProtocolEvent) -> Void) {
        self.id = id
        self.progress = progress
    }

    func consume(_ data: Data, from stream: VideoDownloaderProtocolStream) {
        lock.lock()
        let lines: [String]
        switch stream {
        case .standardOutput: lines = standardOutputDecoder.append(data)
        case .standardError: lines = standardErrorDecoder.append(data)
        }
        lines.forEach(accept)
        lock.unlock()
    }

    func finish() -> String? {
        lock.lock()
        if let line = standardOutputDecoder.finish() { accept(line) }
        if let line = standardErrorDecoder.finish() { accept(line) }
        let path = reportedPath
        lock.unlock()
        return path
    }

    private func accept(_ line: String) {
        guard let event = VideoDownloaderProtocolParser.parse(line: line) else { return }
        if case let .path(path) = event { reportedPath = path }
        let now = Date()
        let shouldPublish: Bool
        if case let .progress(value) = event {
            // One read can contain several progress updates. Drop only
            // duplicates; the first useful value and the final sample matter,
            // especially when speed or ETA becomes available.
            let addsInformation = lastPublishedProgress.map { previous in
                (previous.fraction == nil && value.fraction != nil)
                    || (previous.speedBytesPerSecond == nil && value.speedBytesPerSecond != nil)
                    || (previous.etaSeconds == nil && value.etaSeconds != nil)
            } ?? true
            let meaningfulAdvance: Bool
            if let previous = lastPublishedProgress?.fraction, let current = value.fraction {
                meaningfulAdvance = abs(current - previous) >= 0.005
            } else {
                meaningfulAdvance = false
            }
            shouldPublish = addsInformation
                || meaningfulAdvance
                || value.isNetworkComplete
                || now.timeIntervalSince(lastProgressPublish) >= 0.12
        } else {
            shouldPublish = true
        }
        guard shouldPublish else { return }
        if case let .progress(value) = event {
            lastProgressPublish = now
            lastPublishedProgress = value
        }
        DispatchQueue.main.async { [id, progress] in progress(id, event) }
    }
}

private final class VideoDownloaderPipeDrainSignal {
    private let lock = NSLock()
    private var requested = false

    var isRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    func requestStop() {
        lock.lock()
        requested = true
        lock.unlock()
    }
}

private final class VideoDownloaderDataBox {
    private let lock = NSLock()
    private let limit: Int
    private var data = Data()
    private var overflow = false

    init(limit: Int) { self.limit = max(0, limit) }

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        let remaining = max(0, limit - data.count)
        if remaining > 0 { data.append(chunk.prefix(remaining)) }
        if chunk.count > remaining { overflow = true }
    }

    func snapshot() -> (data: Data, overflow: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (data, overflow)
    }
}

private final class VideoDownloaderProcessOperation {
    let id: UUID
    private let condition = NSCondition()
    private var process: Process?
    private var cancelled = false
    private var didTimeOut = false
    private var didFinish = false
    private var pendingTerminations = 0

    init(id: UUID) { self.id = id }

    var wasCancelled: Bool {
        condition.lock(); defer { condition.unlock() }
        return cancelled
    }

    var timedOut: Bool {
        condition.lock(); defer { condition.unlock() }
        return didTimeOut
    }

    func attach(_ process: Process) {
        condition.lock()
        self.process = process
        let shouldTerminate = cancelled && beginTerminationLocked(process)
        condition.unlock()
        if shouldTerminate { terminate(process) }
    }

    func detach(_ process: Process) {
        condition.lock()
        if self.process === process { self.process = nil }
        condition.unlock()
    }

    func cancel() {
        condition.lock()
        guard !cancelled else { condition.unlock(); return }
        cancelled = true
        let process = self.process
        let shouldTerminate = process.map(beginTerminationLocked) ?? false
        condition.unlock()
        if let process, shouldTerminate { terminate(process) }
    }

    func timeoutIfRunning(_ process: Process) {
        condition.lock()
        guard self.process === process, process.isRunning, !didFinish, !cancelled else {
            condition.unlock()
            return
        }
        didTimeOut = true
        let shouldTerminate = beginTerminationLocked(process)
        condition.unlock()
        if shouldTerminate { terminate(process) }
    }

    func finish() {
        condition.lock()
        while pendingTerminations > 0 { condition.wait() }
        guard !didFinish else { condition.unlock(); return }
        didFinish = true
        process = nil
        condition.broadcast()
        condition.unlock()
    }

    func wait() {
        condition.lock()
        while !didFinish { condition.wait() }
        condition.unlock()
    }

    private func terminate(_ process: Process) {
        let pid = process.processIdentifier
        let initiallyTracked = VideoDownloaderProcessTree.snapshot(of: pid)
        DispatchQueue.global(qos: .userInitiated).async {
            VideoDownloaderProcessTree.terminate(pid, initiallyTracked: initiallyTracked)
            self.condition.lock()
            self.pendingTerminations = max(0, self.pendingTerminations - 1)
            self.condition.broadcast()
            self.condition.unlock()
        }
    }

    private func beginTerminationLocked(_ process: Process) -> Bool {
        guard self.process === process, pendingTerminations == 0 else { return false }
        pendingTerminations += 1
        return true
    }
}
