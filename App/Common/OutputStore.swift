import Foundation
import MeihuaCore
import Photos
import UIKit

/// 结果落盘。所有结果写进 App 的「文稿/输出」，在「文件」App 里可以看到。
enum OutputStore {
    static var outputRoot: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("输出", isDirectory: true)
    }

    static func stamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    static func safeName(_ raw: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = raw.components(separatedBy: bad).joined(separator: "_")
        return cleaned.isEmpty ? "结果" : cleaned
    }

    /// 把结果按原有子目录写成一个文件夹，返回文件夹地址。
    static func writeFolder(_ items: [FileItem], name: String) throws -> URL {
        let folder = outputRoot.appendingPathComponent("\(safeName(name))-\(stamp())", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for item in items {
            guard let rel = ZipCodec.sanitize(item.path) else { continue }
            let url = folder.appendingPathComponent(rel)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try item.data.write(to: url, options: .atomic)
        }
        return folder
    }

    /// 打成一个 zip 写进输出目录，返回 zip 地址（可直接用于分享）。
    static func writeZip(_ items: [FileItem], name: String) throws -> URL {
        let data = try ZipCodec.archive(items)
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        let url = outputRoot.appendingPathComponent("\(safeName(name))-\(stamp()).zip")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// 单个文件直接落盘（例如 .bdi 皮肤），文件名保持原样便于「用百度输入法打开」。
    static func writeSingle(_ item: FileItem) throws -> URL {
        let folder = outputRoot.appendingPathComponent(stamp(), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(safeName(item.fileName))
        try item.data.write(to: url, options: .atomic)
        return url
    }

    /// 把结果里的图片存进相册，返回存入张数。
    static func saveImagesToPhotos(_ items: [FileItem]) async throws -> Int {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw CoreError.unsupported("没有相册写入权限，请到设置里允许")
        }
        let images = items.filter(\.isImage)
        try await PHPhotoLibrary.shared().performChanges {
            for item in images {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: item.data, options: nil)
            }
        }
        return images.count
    }
}