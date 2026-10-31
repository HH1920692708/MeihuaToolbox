import MeihuaCore
import SwiftUI
import UIKit

/// 结果区：数量、缩略图、导出按钮、失败原因。
struct OutputSection: View {
    let session: ToolSession
    let exportName: String

    var body: some View {
        if session.hasOutputs || !session.failures.isEmpty {
            SectionCard("结果") {
                Text(countText).font(.subheadline)
                if session.hasOutputs {
                    ThumbGrid(items: session.outputs)
                    ExportBar(session: session, name: exportName)
                }
                if !session.failures.isEmpty {
                    DisclosureGroup("失败原因") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(session.failures.enumerated()), id: \.offset) { _, line in
                                Text(line).font(.caption).foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var countText: String {
        var text = "成功 \(session.outputs.count) 个"
        if !session.failures.isEmpty { text += "，失败 \(session.failures.count) 个" }
        return text
    }
}

struct ThumbGrid: View {
    let items: [FileItem]
    private let limit = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(items.prefix(limit)) { item in
                    VStack(spacing: 2) {
                        ThumbView(item: item)
                        Text(item.fileName)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if items.count > limit {
                Text("只预览前 \(limit) 个，导出时包含全部 \(items.count) 个")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ThumbView: View {
    let item: FileItem
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill))
            if let image {
                Image(uiImage: image).resizable().scaledToFit().padding(4)
            } else if !item.isImage {
                Image(systemName: "doc").foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .task(id: item.id) {
            guard item.isImage else { return }
            let data = item.data
            image = await Task.detached(priority: .utility) {
                ImageCodec.thumbnail(data, maxPixel: 216).map { UIImage(cgImage: $0) }
            }.value
        }
    }
}

/// 导出：单个文件直接导出原文件（如 .bdi），多个文件打 zip；也可存成文件夹、存相册。
struct ExportBar: View {
    let session: ToolSession
    let name: String

    @State private var shareURL: URL?
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { export(asPackage: true) } label: {
                    Label(session.outputs.count == 1 ? "导出文件" : "打包 zip", systemImage: "shippingbox")
                }
                Button { export(asPackage: false) } label: {
                    Label("存到文件", systemImage: "folder")
                }
                if session.outputs.contains(where: \.isImage) {
                    Button { savePhotos() } label: {
                        Label("存相册", systemImage: "photo")
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(busy)
            if busy { ProgressView() }
            if let shareURL {
                ShareLink(item: shareURL) {
                    Label("分享 \(shareURL.lastPathComponent)", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onChange(of: session.outputVersion) { _, _ in
            shareURL = nil
            message = nil
        }
    }

    private func export(asPackage: Bool) {
        let items = session.outputs
        let name = name
        busy = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<URL, Error> in
                Result {
                    if asPackage {
                        return items.count == 1 ? try OutputStore.writeSingle(items[0])
                                                : try OutputStore.writeZip(items, name: name)
                    }
                    return try OutputStore.writeFolder(items, name: name)
                }
            }.value
            busy = false
            switch result {
            case .success(let url):
                if asPackage { shareURL = url }
                message = "已保存到 文件 › 我的 iPhone › 美化工具箱 › 输出 › \(url.lastPathComponent)"
            case .failure(let error):
                message = error.localizedDescription
            }
        }
    }

    private func savePhotos() {
        let items = session.outputs
        busy = true
        Task {
            do {
                let count = try await OutputStore.saveImagesToPhotos(items)
                message = "已存入相册 \(count) 张"
            } catch {
                message = error.localizedDescription
            }
            busy = false
        }
    }
}