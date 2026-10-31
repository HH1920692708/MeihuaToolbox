import Foundation

/// INI 风格文本（百度皮肤的 .ini / .cnd / .til / default.css / Info.txt 都是这种格式）。
/// 只改动被 set 的行，其余字节原样保留：注释、空行、换行符（CRLF/LF 混用）、BOM、编码。
public struct IniDocument: Sendable {
    public enum TextEncoding: Sendable, Equatable {
        case utf8
        case utf8BOM
        case gb18030
    }

    struct Line: Sendable {
        var content: String
        var terminator: String
    }

    public private(set) var encoding: TextEncoding
    var lines: [Line]

    public init(data: Data) throws {
        let bytes = [UInt8](data)
        let text: String
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            guard let s = String(bytes: bytes.dropFirst(3), encoding: .utf8) else {
                throw CoreError.parseFailed("文本不是有效的 UTF-8")
            }
            encoding = .utf8BOM
            text = s
        } else if let s = String(bytes: bytes, encoding: .utf8) {
            encoding = .utf8
            text = s
        } else if let s = String(bytes: bytes, encoding: ZipCodec.gb18030) {
            encoding = .gb18030
            text = s
        } else {
            throw CoreError.parseFailed("无法识别文本编码")
        }
        lines = IniDocument.split(text)
    }

    public init(text: String, encoding: TextEncoding = .utf8) {
        self.encoding = encoding
        self.lines = IniDocument.split(text)
    }

    public var text: String {
        lines.map { $0.content + $0.terminator }.joined()
    }

    public func data() -> Data {
        let body = text
        switch encoding {
        case .utf8: return Data(body.utf8)
        case .utf8BOM: return Data([0xEF, 0xBB, 0xBF]) + Data(body.utf8)
        case .gb18030: return body.data(using: ZipCodec.gb18030) ?? Data(body.utf8)
        }
    }

    /// 全部节名，按出现顺序；文件开头不在任何节里的键值归到空串节名 ""。
    public var sections: [String] {
        var names: [String] = []
        for line in lines {
            if let name = IniDocument.sectionName(line.content) { names.append(name) }
        }
        return names
    }

    public func hasSection(_ section: String) -> Bool {
        sectionRange(section) != nil
    }

    /// 取值；节名、键名都不区分大小写。值去掉首尾空格和制表符，其余（含 U+2028）原样返回。
    public func value(_ key: String, in section: String) -> String? {
        guard let range = sectionRange(section) else { return nil }
        for i in range {
            if let entry = IniDocument.entry(lines[i].content), entry.key.caseInsensitiveCompare(key) == .orderedSame {
                return entry.value
            }
        }
        return nil
    }

    /// 节内全部键值，按出现顺序。
    public func entries(in section: String) -> [(key: String, value: String)] {
        guard let range = sectionRange(section) else { return [] }
        return range.compactMap { IniDocument.entry(lines[$0].content) }
    }

    /// 改值。已有的键只替换这一行（保留原键名写法）；没有就加在节末尾；节不存在就在文件末尾新建。
    public mutating func setValue(_ value: String, for key: String, in section: String) {
        let newline = dominantTerminator
        if let range = sectionRange(section) {
            for i in range {
                if let entry = IniDocument.entry(lines[i].content), entry.key.caseInsensitiveCompare(key) == .orderedSame {
                    lines[i].content = "\(entry.key)=\(value)"
                    return
                }
            }
            // 插在节内最后一个非空行后面，空行留在节与节之间
            var insertAt = range.upperBound
            while insertAt > range.lowerBound,
                  lines[insertAt - 1].content.trimmingCharacters(in: .whitespaces).isEmpty {
                insertAt -= 1
            }
            if insertAt > 0, lines[insertAt - 1].terminator.isEmpty { lines[insertAt - 1].terminator = newline }
            lines.insert(Line(content: "\(key)=\(value)", terminator: newline), at: insertAt)
            return
        }
        if let last = lines.indices.last, lines[last].terminator.isEmpty, !lines[last].content.isEmpty {
            lines[last].terminator = newline
        }
        if !section.isEmpty { lines.append(Line(content: "[\(section)]", terminator: newline)) }
        lines.append(Line(content: "\(key)=\(value)", terminator: newline))
    }

    /// 删掉一个键所在的行；返回是否删到了。
    @discardableResult
    public mutating func removeValue(_ key: String, in section: String) -> Bool {
        guard let range = sectionRange(section) else { return false }
        for i in range {
            if let entry = IniDocument.entry(lines[i].content), entry.key.caseInsensitiveCompare(key) == .orderedSame {
                lines.remove(at: i)
                return true
            }
        }
        return false
    }

    /// 删掉整节（含节头），返回是否删到了。
    @discardableResult
    public mutating func removeSection(_ section: String) -> Bool {
        guard !section.isEmpty, let range = sectionRange(section) else { return false }
        lines.removeSubrange((range.lowerBound - 1)..<range.upperBound)
        return true
    }

    // MARK: - 内部

    /// 节内容所在的行号区间（不含节头）。同名节出现多次时取第一个。
    func sectionRange(_ section: String) -> Range<Int>? {
        var start: Int?
        if section.isEmpty { start = 0 }
        for (i, line) in lines.enumerated() {
            guard let name = IniDocument.sectionName(line.content) else { continue }
            if let s = start { return s..<i }
            if name.caseInsensitiveCompare(section) == .orderedSame { start = i + 1 }
        }
        if let s = start { return s..<lines.count }
        return nil
    }

    var dominantTerminator: String {
        let crlf = lines.filter { $0.terminator == "\r\n" }.count
        let lf = lines.filter { $0.terminator == "\n" }.count
        return crlf >= lf && crlf > 0 ? "\r\n" : (lf > 0 ? "\n" : "\r\n")
    }

    static let trimSet = CharacterSet(charactersIn: " \t")

    static func sectionName(_ content: String) -> String? {
        let s = content.trimmingCharacters(in: trimSet)
        guard s.hasPrefix("["), s.hasSuffix("]"), s.count >= 2 else { return nil }
        return String(s.dropFirst().dropLast()).trimmingCharacters(in: trimSet)
    }

    static func entry(_ content: String) -> (key: String, value: String)? {
        let s = content.trimmingCharacters(in: trimSet)
        guard !s.hasPrefix(";"), !s.hasPrefix("#"), !s.hasPrefix("["), let eq = content.firstIndex(of: "=") else {
            return nil
        }
        let key = content[..<eq].trimmingCharacters(in: trimSet)
        guard !key.isEmpty else { return nil }
        let value = content[content.index(after: eq)...].trimmingCharacters(in: trimSet)
        return (key, value)
    }

    /// 按 \r\n、\n、\r 切行并记住各自的换行符。按 Unicode 标量扫描，避免 "\r\n" 被当成一个字符。
    static func split(_ text: String) -> [Line] {
        var result: [Line] = []
        var current = String.UnicodeScalarView()
        var pendingCR = false
        for scalar in text.unicodeScalars {
            if pendingCR {
                pendingCR = false
                if scalar == "\n" {
                    result.append(Line(content: String(current), terminator: "\r\n"))
                    current = String.UnicodeScalarView()
                    continue
                }
                result.append(Line(content: String(current), terminator: "\r"))
                current = String.UnicodeScalarView()
            }
            if scalar == "\r" {
                pendingCR = true
            } else if scalar == "\n" {
                result.append(Line(content: String(current), terminator: "\n"))
                current = String.UnicodeScalarView()
            } else {
                current.append(scalar)
            }
        }
        if pendingCR {
            result.append(Line(content: String(current), terminator: "\r"))
        } else if !current.isEmpty {
            result.append(Line(content: String(current), terminator: ""))
        }
        return result
    }
}