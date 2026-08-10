// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct PanelVideoDownloaderView: View {
    let close: () -> Void

    var body: some View {
        VideoDownloaderWorkspaceView(compact: true, onClose: close)
    }
}

struct VideoDownloaderWorkspaceView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var workflow = VideoDownloaderWorkflow.shared
    let compact: Bool
    var onClose: (() -> Void)? = nil

    private var text: VideoDownloaderStrings { FeatureStrings.videoDownloader(l10n.language) }
    private var controlsLocked: Bool { workflow.phase.locksRequest }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            header
            sourceField

            if workflow.phase == .inspecting {
                Label(text.inspecting, systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let validationError = workflow.validationError {
                message(text.message(for: validationError), color: .orange)
            }
            if let media = workflow.media {
                mediaDetails(media)
                requestControls(media)
                if media.videoAvailability == .unavailable {
                    message(text.errorNoVideo, color: .orange)
                }
                if media.audioAvailability == .unavailable {
                    message(text.errorNoAudio, color: .orange)
                }
            }
            destinationRow
            if !workflow.missingTools.isEmpty || workflow.phase == .settingUp {
                VideoDownloaderDependencyCard(alwaysShow: false)
            }
            stateControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label(text.pageTitle, systemImage: "arrow.down.circle")
                    .font(compact ? .headline : .title2.weight(.semibold))
                Spacer(minLength: 0)
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help(l10n.s.menuClose)
                    .accessibilityLabel(l10n.s.menuClose)
                }
            }
        }
    }

    private var sourceField: some View {
        HStack(spacing: 7) {
            TextField(text.urlPlaceholder,
                      text: Binding(get: { workflow.sourceText },
                                    set: workflow.setSourceText))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 2)
                .disabled(controlsLocked)
                .help(text.urlHelp)
                .accessibilityLabel(text.urlPlaceholder)
            Button(text.paste) { workflow.pasteURL() }
                .disabled(controlsLocked)
        }
    }

    private func mediaDetails(_ media: VideoDownloaderMedia) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let thumbnailURL = media.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06))
                            Image(systemName: "photo").foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(width: compact ? 94 : 132, height: compact ? 58 : 78)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityLabel(text.thumbnail)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(media.title)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .lineLimit(2)
                if let uploader = media.uploader, !uploader.isEmpty {
                    Label(uploader, systemImage: "person")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(text.uploader): \(uploader)")
                }
                if let duration = media.duration {
                    Label(durationText(duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(text.duration): \(durationText(duration))")
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func requestControls(_ media: VideoDownloaderMedia) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $workflow.mode) {
                Text(text.video).tag(VideoDownloaderOutputMode.video)
                Text(text.mp3).tag(VideoDownloaderOutputMode.mp3)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(controlsLocked)

            if workflow.mode == .video {
                Picker(text.quality, selection: $workflow.quality) {
                    Text(text.best).tag(VideoDownloaderQuality.best)
                    ForEach(media.heights, id: \.self) { height in
                        Text(String(format: text.heightFormat, height))
                            .tag(VideoDownloaderQuality.height(height))
                    }
                }
                .disabled(controlsLocked || !media.canAttemptVideo)
            }

            HStack(spacing: 12) {
                Toggle(text.subtitles, isOn: $workflow.subtitlesEnabled)
                    .disabled(controlsLocked || media.subtitles.isEmpty)

                Spacer(minLength: 0)

                Picker(text.subtitles,
                       selection: Binding(get: {
                           workflow.subtitle?.id ?? media.subtitles.first?.id ?? ""
                       }, set: { id in
                           workflow.subtitle = media.subtitles.first { $0.id == id }
                       })) {
                    ForEach(media.subtitles) { track in
                        Text(subtitleLabel(track)).tag(track.id)
                    }
                }
                .labelsHidden()
                .accessibilityLabel(text.subtitles)
                .disabled(controlsLocked || !workflow.subtitlesEnabled || media.subtitles.isEmpty)
            }
        }
    }

    private var destinationRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(text.destination)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(workflow.destination.lastPathComponent)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(text.choose, action: chooseDestination)
                .disabled(controlsLocked)
        }
        .help(workflow.destination.path)
    }

    @ViewBuilder
    private var stateControls: some View {
        switch workflow.phase {
        case .downloading, .finalizing, .cancelling:
            activeDownload
        case .completed:
            completionView
        case .failed:
            failureView
        case .cancelled:
            VStack(alignment: .leading, spacing: 7) {
                message(text.cancelled, color: .secondary)
                Button(text.retry) { workflow.retry() }
            }
        case .settingUp:
            EmptyView()
        default:
            Button(workflow.mode == .video ? text.downloadVideo : text.downloadMP3) {
                workflow.startDownload()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .disabled(!workflow.canDownload)
        }
    }

    private var activeDownload: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(workflow.activeTitle ?? workflow.media?.title ?? text.downloading)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
            qualityFallbackNotice
            if let fraction = workflow.progress.fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
            HStack(spacing: 8) {
                Text(activeStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if workflow.phase != .cancelling {
                    Button(text.cancel) { workflow.cancelActiveOperation() }
                }
            }
        }
    }

    private var activeStatus: String {
        if workflow.phase == .cancelling { return text.cancelling }
        if workflow.phase == .finalizing { return text.finalizing }
        var parts = [text.downloading]
        if let fraction = workflow.progress.fraction {
            parts.append(String(format: text.percentFormat, fraction * 100))
        }
        if let speed = workflow.progress.speedBytesPerSecond {
            parts.append(String(format: text.speedFormat, speedText(speed)))
        }
        if let eta = workflow.progress.etaSeconds {
            parts.append(String(format: text.etaFormat, durationText(eta)))
        }
        return parts.joined(separator: " · ")
    }

    private var completionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(text.complete, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 12, weight: .semibold))
            if let file = workflow.completedFile {
                Text(file.lastPathComponent)
                    .font(.caption)
                    .lineLimit(2)
                    .help(file.path)
            }
            qualityFallbackNotice
            HStack {
                Button(text.downloadAnother) { workflow.downloadAnother() }
                Spacer(minLength: 0)
                Button(text.revealFinder) { workflow.revealCompletedFile() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var qualityFallbackNotice: some View {
        if let fallback = workflow.qualityFallback {
            Label(String(format: text.qualityFallbackFormat,
                         fallback.requestedHeight,
                         fallback.actualHeight),
                  systemImage: "arrow.down.right.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var failureView: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(text.failureTitle, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            if let failure = workflow.failure {
                Text(text.message(for: failure))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(text.retry) { workflow.retry() }
        }
    }

    private func message(_ value: String, color: Color) -> some View {
        Text(value)
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func subtitleLabel(_ track: VideoDownloaderSubtitleTrack) -> String {
        let language = VideoDownloaderSubtitleSelection.localizedName(for: track,
                                                                       appLanguage: l10n.language)
        return language + " · " + (track.source == .manual ? text.manual : text.automatic)
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let remainder = value % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%d:%02d", minutes, remainder)
    }

    private func speedText(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = max(0, bytes)
        var index = 0
        while value >= 1000, index < units.count - 1 { value /= 1000; index += 1 }
        return value >= 10 || index == 0
            ? String(format: "%.0f %@", value, units[index])
            : String(format: "%.1f %@", value, units[index])
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = workflow.destination
        if panel.runModal() == .OK, let url = panel.url {
            workflow.setDestination(url)
        }
    }
}

struct VideoDownloaderDependencyCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var workflow = VideoDownloaderWorkflow.shared
    let alwaysShow: Bool

    private var text: VideoDownloaderStrings { FeatureStrings.videoDownloader(l10n.language) }

    var body: some View {
        if alwaysShow || workflow.isProbingDependencies
            || !workflow.missingTools.isEmpty || workflow.phase == .settingUp {
            VStack(alignment: .leading, spacing: 8) {
                Label(text.dependencies, systemImage: "shippingbox")
                    .font(.system(size: 12, weight: .semibold))
                ForEach(VideoDownloaderTool.allCases, id: \.self) { tool in
                    HStack {
                        Text(tool.executableName)
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        if workflow.dependencyState.value == nil {
                            ProgressView().controlSize(.small)
                            Text(text.checkingTools).font(.caption).foregroundStyle(.secondary)
                        } else {
                            let available = !workflow.missingTools.contains(tool)
                            Label(available ? l10n.s.homebrewInstalledBadge : l10n.s.homebrewNotInstalledBadge,
                                  systemImage: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(available ? .green : .orange)
                        }
                    }
                }
                if !workflow.missingTools.isEmpty {
                    Text(String(format: text.missingToolsFormat,
                                workflow.missingTools.map(\.executableName).sorted().joined(separator: ", ")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(VideoDownloaderDependencySupport.brewPath() == nil
                         ? text.terminalSetupNote : text.brewSetupNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if workflow.phase == .settingUp {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(text.checkingTools).font(.caption)
                        Spacer()
                        if workflow.canCancelSetup {
                            Button(text.cancel) { workflow.cancelActiveOperation() }
                        }
                    }
                } else if !workflow.missingTools.isEmpty {
                    Button(VideoDownloaderDependencySupport.brewPath() == nil
                           ? text.setUpDownloader : text.installMissingTools) {
                        workflow.setupDependencies()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!workflow.canSetupDependencies)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.045)))
        }
    }
}

struct VideoDownloaderSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var workflow = VideoDownloaderWorkflow.shared
    @AppStorage(DefaultsKey.panelUtilityVideoDownloader) private var showInPanel = true
    @AppStorage(DefaultsKey.videoDownloaderEmbedThumbnail) private var thumbnail = true
    @AppStorage(DefaultsKey.videoDownloaderEmbedMetadata) private var metadata = true
    @AppStorage(DefaultsKey.videoDownloaderEmbedChapters) private var chapters = true
    @AppStorage(DefaultsKey.videoDownloaderEmbedSubtitle) private var subtitle = true
    @AppStorage(DefaultsKey.videoDownloaderLyrics) private var lyrics = true

    private var text: VideoDownloaderStrings { FeatureStrings.videoDownloader(l10n.language) }

    var body: some View {
        Form {
            Section {
                Text(text.settingsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(text.showInPanel, isOn: $showInPanel)
            }
            Section(text.defaultLocation) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workflow.destination.lastPathComponent)
                        Text(workflow.destination.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button(text.choose, action: chooseDestination)
                    Button(text.resetDownloads) { workflow.resetDestination() }
                }
            }
            Section {
                Toggle(text.embedThumbnail, isOn: $thumbnail)
                Toggle(text.embedMetadata, isOn: $metadata)
                Toggle(text.embedChapters, isOn: $chapters)
                Toggle(text.embedSubtitle, isOn: $subtitle)
                Toggle(text.lyrics, isOn: $lyrics)
            }
            Section(text.dependencies) {
                VideoDownloaderDependencyCard(alwaysShow: true)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(text.pageTitle)
        .padding()
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = workflow.destination
        if panel.runModal() == .OK, let url = panel.url { workflow.setDestination(url) }
    }
}
