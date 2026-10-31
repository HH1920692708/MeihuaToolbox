import Foundation

/// 工具之间流转的最小单位：一个相对路径加它的字节内容。
/// 路径用 `/` 分隔，打包成 zip 时原样作为条目名。
public struct FileItem: Sendable, Hashable, Identifiable {
    public var path: String
    public var data: Data

    public var id: String { path }

    public init(path: String, data: Data) {
        self.path = path
        self.data = data
    }

    public var fileName: String {
        (path as NSString).lastPathComponent
    }

    public var baseName: String {
        (fileName as NSString).deletingPathExtension
    }

    public var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    /// 不含文件名的目录部分；在根目录时为空串。
    public var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir == "." ? "" : dir
    }

    public var isImage: Bool {
        ["png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "bmp", "tif", "tiff"].contains(fileExtension)
    }

    /// 换扩展名，目录与主文件名不变。
    public func replacingExtension(_ ext: String) -> String {
        FileItem.join(directory, baseName + "." + ext)
    }

    /// 拼接相对路径，自动忽略空段。
    public static func join(_ parts: String...) -> String {
        parts.filter { !$0.isEmpty }.joined(separator: "/")
    }
}

public enum CoreError: LocalizedError, Sendable, Equatable {
    case decodeFailed(String)
    case encodeFailed(String)
    case invalidSize(Int, Int)
    case zipFailed(String)
    case zipTooLarge
    case parseFailed(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .decodeFailed(let name): return "无法读取图片：\(name)"
        case .encodeFailed(let name): return "无法写出图片：\(name)"
        case .invalidSize(let w, let h): return "尺寸不合法：\(w)×\(h)"
        case .zipFailed(let reason): return "压缩包处理失败：\(reason)"
        case .zipTooLarge: return "压缩包解开后太大（超过 1GB），已停止"
        case .parseFailed(let reason): return "解析失败：\(reason)"
        case .unsupported(let reason): return "暂不支持：\(reason)"
        }
    }
}