import Foundation

public struct BatchResult: Sendable {
    public var outputs: [FileItem] = []
    /// 失败项：文件路径 + 原因。批处理遇错不中断，最后一起列出。
    public var failures: [String] = []

    public init(outputs: [FileItem] = [], failures: [String] = []) {
        self.outputs = outputs
        self.failures = failures
    }
}

public enum Batch {
    /// 逐个处理输入；单个失败只记录，不影响其他文件。
    /// `transform` 可以返回 0 个（跳过）或多个输出（例如一图出多尺寸）。
    public static func map(
        _ inputs: [FileItem],
        progress: (Double) -> Void = { _ in },
        transform: (FileItem) throws -> [FileItem]
    ) -> BatchResult {
        var result = BatchResult()
        let total = max(inputs.count, 1)
        for (index, item) in inputs.enumerated() {
            do {
                let produced = try autoreleasepool { try transform(item) }
                result.outputs.append(contentsOf: produced)
            } catch {
                result.failures.append("\(item.path)：\(error.localizedDescription)")
            }
            progress(Double(index + 1) / Double(total))
        }
        var used = Set<String>()
        result.outputs = result.outputs.map {
            FileItem(path: ZipCodec.uniquePath($0.path, used: &used), data: $0.data)
        }
        return result
    }

    /// 只保留能当图片处理的输入。
    public static func images(_ inputs: [FileItem]) -> [FileItem] {
        inputs.filter(\.isImage)
    }
}