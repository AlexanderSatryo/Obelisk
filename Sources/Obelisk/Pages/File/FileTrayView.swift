import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Renders the File module inside the expanded Obelisk dashboard.
/// Two equal drop areas separated by a single hairline: File (staging shelf) on the left,
/// AirDrop (instant sharing) on the right. Each area carries one label only.
public struct FileTrayView: View {
    @ObservedObject var trayService: FileTrayService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared

    @State private var isShelfTargeted: Bool = false
    @State private var isAirDropTargeted: Bool = false
    @State private var isShelfHovered: Bool = false
    @State private var isAirDropHovered: Bool = false
    @State private var hoveredFileId: UUID? = nil

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            shelfArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 96)
                .padding(.horizontal, 10)

            airDropArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 114)
        .padding(.top, 2)
    }

    // MARK: - File Area

    private var shelfArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isShelfTargeted ? 0.12 : (isShelfHovered ? 0.06 : 0.0)))

            if trayService.files.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: isShelfTargeted ? "arrow.down.to.line" : "tray.and.arrow.down")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(height: 30)

                    Text("File")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("File")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))

                        Spacer()

                        Button(action: { trayService.promptAddFiles() }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()

                        Button(action: { trayService.clearAll() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(trayService.files) { file in
                                fileTile(file)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .contentShape(Rectangle())
        .onHover { isShelfHovered = $0 }
        .onTapGesture {
            if trayService.files.isEmpty {
                trayService.promptAddFiles()
            }
        }
        .contextMenu {
            Button("Add Files...") { trayService.promptAddFiles() }
            if !trayService.files.isEmpty {
                Button("Clear All") { trayService.clearAll() }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isShelfTargeted) { providers in
            loadURLs(from: providers) { urls in
                trayService.addFiles(urls: urls)
            }
        }
        .pointingHandCursor()
    }

    // MARK: - AirDrop Area

    private var airDropArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isAirDropTargeted ? 0.12 : (isAirDropHovered ? 0.06 : 0.0)))

            VStack(spacing: 9) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(height: 30)

                Text("AirDrop")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .contentShape(Rectangle())
        .onHover { isAirDropHovered = $0 }
        .onTapGesture {
            trayService.shareViaAirDrop()
        }
        .onDrop(of: [.fileURL], isTargeted: $isAirDropTargeted) { providers in
            loadURLs(from: providers) { urls in
                trayService.shareViaAirDrop(targetFiles: urls)
            }
        }
        .pointingHandCursor()
    }

    // MARK: - File Tile

    private func fileTile(_ file: TrayFile) -> some View {
        let isHovered = hoveredFileId == file.id
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: file.iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)

                if isHovered {
                    Button(action: { trayService.removeFile(id: file.id) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white, Color.black.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -5)
                }
            }

            Text(file.name)
                .font(.system(size: 9.5, weight: .regular))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 58)
        }
        .contentShape(Rectangle())
        .onHover { hoveredFileId = $0 ? file.id : nil }
        .onTapGesture(count: 2) {
            trayService.openFile(url: file.url)
        }
        .onDrag {
            NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Open") { trayService.openFile(url: file.url) }
            Button("Reveal in Finder") { trayService.revealInFinder(url: file.url) }
            Button("Remove") { trayService.removeFile(id: file.id) }
        }
    }

    // MARK: - Drop Helpers

    private func loadURLs(from providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) -> Bool {
        let lock = NSLock()
        var found: [URL] = []
        let group = DispatchGroup()

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                var resolved: URL? = nil
                if let data = item as? Data {
                    resolved = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolved = url
                }
                if let resolved {
                    lock.lock()
                    found.append(resolved)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            guard !found.isEmpty else { return }
            let urls = found
            Task { @MainActor in completion(urls) }
        }
        return true
    }
}
