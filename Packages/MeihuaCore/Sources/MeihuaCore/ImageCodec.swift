import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageFormat: Sendable, Hashable {
    case png
    case jpeg(quality: Double)

    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        }
    }
}

public enum ImageCodec {
    /// 解码第一帧，并按 EXIF 方向转正。像素尺寸不做缩放。
    public static func decode(_ data: Data, name: String = "") throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw CoreError.decodeFailed(name)
        }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if orientation == 1 {
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw CoreError.decodeFailed(name)
            }
            return image
        }
        // 方向不是 1 时用缩略图接口一次性转正；尺寸给原图长边，避免缩小。
        let w = (props?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let h = (props?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(w, h, 1)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CoreError.decodeFailed(name)
        }
        return image
    }

    /// 只读像素尺寸，不解码整图。
    public static func pixelSize(of data: Data) -> PixelSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue else {
            return nil
        }
        return PixelSize(width: w, height: h)
    }

    /// 生成预览缩略图（转正），长边不超过 maxPixel。
    public static func thumbnail(_ data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// 编码为 PNG 或 JPEG。JPEG 没有透明通道，先铺白底，否则透明处会变黑。
    public static func encode(_ image: CGImage, as format: ImageFormat, name: String = "") throws -> Data {
        var output = image
        var properties: [CFString: Any] = [:]
        if case .jpeg(let quality) = format {
            output = try Render.flatten(image, background: RGBA8.white)
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1)
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data as CFMutableData, format.utType.identifier as CFString, 1, nil
        ) else {
            throw CoreError.encodeFailed(name)
        }
        CGImageDestinationAddImage(dest, output, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw CoreError.encodeFailed(name)
        }
        return data as Data
    }
}