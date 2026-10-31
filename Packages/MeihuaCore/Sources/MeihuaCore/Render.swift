import CoreGraphics
import Foundation

public struct PixelSize: Sendable, Hashable, Codable, CustomStringConvertible {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var description: String { "\(width)×\(height)" }
    public var isValid: Bool { width > 0 && height > 0 && width <= 16384 && height <= 16384 }
}

public enum ResizeMode: String, Sendable, CaseIterable, Identifiable {
    /// 拉伸铺满，不保持比例
    case stretch
    /// 完整放入，四周留透明
    case fit
    /// 保持比例铺满，超出部分裁掉
    case fill

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .stretch: return "拉伸"
        case .fit: return "完整放入"
        case .fill: return "裁切铺满"
        }
    }
}

/// 所有像素级绘制都走这里，按像素尺寸建画布，与屏幕倍率无关。
public enum Render {
    public static let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// 8 位 RGBA、预乘透明的画布，初始全透明。
    /// 注意：CGContext 原点在左下角；画 CGImage 时图片本身会正着出来。
    public static func makeContext(_ size: PixelSize) throws -> CGContext {
        guard size.isValid,
              let ctx = CGContext(
                data: nil,
                width: size.width,
                height: size.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw CoreError.invalidSize(size.width, size.height)
        }
        ctx.interpolationQuality = .high
        return ctx
    }

    public static func image(from ctx: CGContext) throws -> CGImage {
        guard let image = ctx.makeImage() else {
            throw CoreError.encodeFailed("render")
        }
        return image
    }

    /// 计算源图放进目标尺寸时的绘制矩形（左下原点坐标）。
    public static func drawRect(source: PixelSize, target: PixelSize, mode: ResizeMode) -> CGRect {
        let tw = CGFloat(target.width), th = CGFloat(target.height)
        let sw = CGFloat(source.width), sh = CGFloat(source.height)
        switch mode {
        case .stretch:
            return CGRect(x: 0, y: 0, width: tw, height: th)
        case .fit, .fill:
            let scale = mode == .fit ? min(tw / sw, th / sh) : max(tw / sw, th / sh)
            let w = sw * scale, h = sh * scale
            return CGRect(x: (tw - w) / 2, y: (th - h) / 2, width: w, height: h)
        }
    }

    public static func resize(_ image: CGImage, to target: PixelSize, mode: ResizeMode) throws -> CGImage {
        let ctx = try makeContext(target)
        let source = PixelSize(width: image.width, height: image.height)
        ctx.draw(image, in: drawRect(source: source, target: target, mode: mode))
        return try self.image(from: ctx)
    }

    /// 按左上原点的像素矩形裁切；矩形会先夹到图片范围内。
    public static func crop(_ image: CGImage, x: Int, y: Int, width: Int, height: Int) throws -> CGImage {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let rect = CGRect(x: x, y: y, width: width, height: height).intersection(bounds).integral
        guard !rect.isEmpty, let cropped = image.cropping(to: rect) else {
            throw CoreError.invalidSize(width, height)
        }
        return cropped
    }

    /// 把透明部分铺上底色。
    public static func flatten(_ image: CGImage, background: RGBA8) throws -> CGImage {
        let size = PixelSize(width: image.width, height: image.height)
        let ctx = try makeContext(size)
        ctx.setFillColor(background.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return try self.image(from: ctx)
    }
}