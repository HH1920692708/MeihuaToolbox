import Foundation
import MeihuaCore
import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 一个工具页面的状态：输入、输出、进度、错误。每个工具页 `@State private var session = ToolSession()`。
@MainActor
@Observable
final class ToolSession {
    var inputs: [FileItem] = []
    var outputs: [FileItem] = []
    var failures: [String] = []
    var progress: Double = 0
    var isRunning = false
    var isLoading = false
    var errorMessage: String?
    /// 每次产生新输出时加一，导出区据此清掉旧的分享链接。
    var outputVersion = 0
    private var photoCounter = 0

    var hasOutputs: Bool { !outputs.isEmpty }

    func clearInputs() {
        inputs = []
        photoCounter = 0
    }

    /// 在后台跑批处理。`work` 拿到输入快照和进度回调，返回结果；抛错时整批视为失败。
    func run(_ work: @escaping @Sendable (_ inputs: [FileItem], _ progress: @escaping @Sendable (Double) -> Void) throws -> BatchResult) {
        guard !isRunning else { return }
        let snapshot = inputs
        isRunning = true
        progress = 0
        errorMessage = nil
        failures = []
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<BatchResult, Error> in
                let report: @Sendable (Double) -> Void = { value in
                    Task { @MainActor [weak self] in self?.progress = value }
                }
                return Result { try work(snapshot, report) }
            }.value
            switch result {
            case .success(let batch):
                outputs = batch.outputs
                failures = batch.failures
                progress = 1
            case .failure(let error):
                outputs = []
                errorMessage = error.localizedDescription
            }
            outputVersion += 1
            isRunning = false
        }
    }

    /// 读入「文件」里选的文件；`expandZip` 为真时把 zip 解开成多个输入。
    func importFiles(_ urls: [URL], expandZip: Bool) {
        isLoading = true
        errorMessage = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[FileItem], Error> in
                Result { try ToolSession.load(urls, expandZip: expandZip) }
            }.value
            switch result {
            case .success(let items): append(items)
            case .failure(let error): errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// 读入相册里选的照片，保持原始编码（HEIC 也照收）。
    func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            var loaded: [FileItem] = []
            for item in items {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                    photoCounter += 1
                    let ext = ToolSession.fileExtension(for: item.supportedContentTypes.first)
                    loaded.append(FileItem(path: "photo_\(photoCounter).\(ext)", data: data))
                } catch {
                    errorMessage = "有照片读取失败：\(error.localizedDescription)"
                }
            }
            append(loaded)
            isLoading = false
        }
    }

    private func append(_ items: [FileItem]) {
        var used = Set(inputs.map(\.path))
        inputs += items.map { FileItem(path: ZipCodec.uniquePath($0.path, used: &used), data: $0.data) }
    }

    nonisolated static func load(_ urls: [URL], expandZip: Bool) throws -> [FileItem] {
        var items: [FileItem] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            // 不用内存映射：安全作用域结束后再读映射页可能失败。
            let data = try Data(contentsOf: url)
            if expandZip && url.pathExtension.lowercased() == "zip" {
                items += try ZipCodec.extract(data)
            } else {
                items.append(FileItem(path: url.lastPathComponent, data: data))
            }
        }
        return items
    }

    nonisolated static func fileExtension(for type: UTType?) -> String {
        guard let type else { return "png" }
        if type.conforms(to: .jpeg) { return "jpg" }
        if type.conforms(to: .heic) || type.conforms(to: .heif) { return "heic" }
        return type.preferredFilenameExtension ?? "png"
    }
}