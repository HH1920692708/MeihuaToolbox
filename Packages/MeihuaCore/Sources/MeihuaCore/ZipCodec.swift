import Foundation
import ZIPFoundation

/// zip 读写。读入时做防护：限制条目数与解压总量，丢弃越界路径和系统垃圾文件。
public enum ZipCodec {
    public static let maxEntries = 20_000
    public static let maxEntryBytes: UInt64 = 256 * 1024 * 1024
    public static let maxTotalBytes: UInt64 = 1024 * 1024 * 1024

    /// 解开 zip，只返回普通文件；路径统一成 `a/b/c.png` 形式。
    public static func extract(_ data: Data) throws -> [FileItem] {
        let archive: Archive
        do {
            archive = try Archive(data: data, accessMode: .read)
        } catch {
            throw CoreError.zipFailed("不是有效的 zip 文件")
        }
        var items: [FileItem] = []
        var used = Set<String>()
        var total: UInt64 = 0
        var count = 0
        for entry in archive {
            count += 1
            guard count <= maxEntries else { throw CoreError.zipFailed("条目超过 \(maxEntries) 个") }
            guard entry.type == .file else { continue }
            guard let path = sanitize(decodePath(entry)), !isJunk(path) else { continue }
            guard entry.uncompressedSize <= maxEntryBytes else {
                throw CoreError.zipFailed("单个文件超过 256MB：\(path)")
            }
            total += entry.uncompressedSize
            guard total <= maxTotalBytes else { throw CoreError.zipTooLarge }

            var content = Data()
            do {
                _ = try archive.extract(entry) { chunk in
                    // 头部声明的大小可以伪造，按实际解出的字节再卡一次。
                    guard UInt64(content.count + chunk.count) <= maxEntryBytes else {
                        throw CoreError.zipTooLarge
                    }
                    content.append(chunk)
                }
            } catch let error as CoreError {
                throw error
            } catch {
                throw CoreError.zipFailed("解压 \(path) 出错")
            }
            let unique = uniquePath(path, used: &used)
            items.append(FileItem(path: unique, data: content))
        }
        return items
    }

    /// 打包成 zip（deflate）。重名路径自动加 `_2`、`_3` 后缀。
    public static func archive(_ items: [FileItem]) throws -> Data {
        let archive: Archive
        do {
            archive = try Archive(accessMode: .create)
        } catch {
            throw CoreError.zipFailed("无法创建压缩包")
        }
        var used = Set<String>()
        for item in items {
            guard let clean = sanitize(item.path) else { continue }
            let path = uniquePath(clean, used: &used)
            let payload = item.data
            do {
                try archive.addEntry(
                    with: path,
                    type: .file,
                    uncompressedSize: Int64(payload.count),
                    compressionMethod: .deflate
                ) { position, size in
                    let start = payload.startIndex + Int(position)
                    return payload.subdata(in: start..<(start + size))
                }
            } catch {
                throw CoreError.zipFailed("写入 \(path) 出错")
            }
        }
        guard let data = archive.data else { throw CoreError.zipFailed("压缩包为空") }
        return data
    }

    /// 文件名优先按 UTF-8 解；不是合法 UTF-8 时按 GB18030 解（中文 Windows 打的包），最后退回 CP437。
    static func decodePath(_ entry: Entry) -> String {
        let utf8 = entry.path(using: .utf8)
        if !utf8.isEmpty { return utf8 }
        let gb = entry.path(using: gb18030)
        if !gb.isEmpty { return gb }
        return entry.path
    }

    static let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
    ))

    /// 去掉开头的 `/`、`.`、空段；含 `..` 的路径整条丢弃，防止写出包外。
    public static func sanitize(_ raw: String) -> String? {
        let parts = raw.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { $0 != "." }
        guard !parts.isEmpty, !parts.contains("..") else { return nil }
        return parts.joined(separator: "/")
    }

    static func isJunk(_ path: String) -> Bool {
        let parts = path.split(separator: "/").map(String.init)
        if parts.contains("__MACOSX") { return true }
        guard let name = parts.last else { return true }
        return name.hasPrefix("._") || name == ".DS_Store" || name == "Thumbs.db" || name == "desktop.ini"
    }

    /// 重名时在扩展名前加 `_2`、`_3`……
    public static func uniquePath(_ path: String, used: inout Set<String>) -> String {
        guard used.contains(path) else {
            used.insert(path)
            return path
        }
        let ns = path as NSString
        let ext = ns.pathExtension
        let stem = ns.deletingPathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem)_\(n)" : "\(stem)_\(n).\(ext)"
            if !used.contains(candidate) {
                used.insert(candidate)
                return candidate
            }
            n += 1
        }
    }
}