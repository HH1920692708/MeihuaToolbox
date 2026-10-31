import CoreGraphics
import Foundation

/// 非预乘的 8 位 RGBA 颜色。
public struct RGBA8: Sendable, Hashable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public static let white = RGBA8(r: 255, g: 255, b: 255)
    public static let black = RGBA8(r: 0, g: 0, b: 0)
    public static let clear = RGBA8(r: 0, g: 0, b: 0, a: 0)

    /// 解析 `RRGGBB`、`#RRGGBB`、`AARRGGBB`（百度皮肤的写法，透明度在前）。
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.lowercased().hasPrefix("0x") { s.removeFirst(2) }
        guard s.count == 6 || s.count == 8, let value = UInt32(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(r: UInt8((value >> 16) & 0xFF), g: UInt8((value >> 8) & 0xFF), b: UInt8(value & 0xFF))
        } else {
            self.init(r: UInt8((value >> 16) & 0xFF), g: UInt8((value >> 8) & 0xFF), b: UInt8(value & 0xFF),
                      a: UInt8((value >> 24) & 0xFF))
        }
    }

    /// 输出 `RRGGBB`；不透明时省略透明度，否则输出 `AARRGGBB`。小写，与百度样本一致。
    public var hexString: String {
        if a == 255 {
            return String(format: "%02x%02x%02x", r, g, b)
        }
        return String(format: "%02x%02x%02x%02x", a, r, g, b)
    }

    public var cgColor: CGColor {
        CGColor(colorSpace: Render.sRGB,
                components: [CGFloat(r) / 255, CGFloat(g) / 255, CGFloat(b) / 255, CGFloat(a) / 255])
            ?? CGColor(gray: 0, alpha: 1)
    }
}

/// 非预乘 RGBA 像素缓冲，行优先、第 0 行在最上面。逐像素算法都在它上面做。
public struct RGBABitmap: Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, fill: RGBA8 = .clear) {
        self.width = width
        self.height = height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        if fill != .clear {
            for i in stride(from: 0, to: buffer.count, by: 4) {
                buffer[i] = fill.r; buffer[i + 1] = fill.g; buffer[i + 2] = fill.b; buffer[i + 3] = fill.a
            }
        }
        self.pixels = buffer
    }

    public init(_ image: CGImage) throws {
        let size = PixelSize(width: image.width, height: image.height)
        guard size.isValid else { throw CoreError.invalidSize(size.width, size.height) }
        var buffer = [UInt8](repeating: 0, count: size.width * size.height * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: size.width, height: size.height,
                bitsPerComponent: 8, bytesPerRow: size.width * 4, space: Render.sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            return true
        }
        guard drawn else { throw CoreError.decodeFailed("bitmap") }
        RGBABitmap.unpremultiply(&buffer)
        self.width = size.width
        self.height = size.height
        self.pixels = buffer
    }

    @inline(__always)
    public func offset(_ x: Int, _ y: Int) -> Int { (y * width + x) * 4 }

    public subscript(x: Int, y: Int) -> RGBA8 {
        get {
            let o = offset(x, y)
            return RGBA8(r: pixels[o], g: pixels[o + 1], b: pixels[o + 2], a: pixels[o + 3])
        }
        set {
            let o = offset(x, y)
            pixels[o] = newValue.r; pixels[o + 1] = newValue.g; pixels[o + 2] = newValue.b; pixels[o + 3] = newValue.a
        }
    }

    public func makeImage() throws -> CGImage {
        var buffer = pixels
        RGBABitmap.premultiply(&buffer)
        let image: CGImage? = buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: Render.sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return ctx.makeImage()
        }
        guard let image else { throw CoreError.encodeFailed("bitmap") }
        return image
    }

    static func unpremultiply(_ buffer: inout [UInt8]) {
        buffer.withUnsafeMutableBufferPointer { p in
            var i = 0
            while i < p.count {
                let a = Int(p[i + 3])
                if a != 0 && a != 255 {
                    p[i] = UInt8(min(255, (Int(p[i]) * 255 + a / 2) / a))
                    p[i + 1] = UInt8(min(255, (Int(p[i + 1]) * 255 + a / 2) / a))
                    p[i + 2] = UInt8(min(255, (Int(p[i + 2]) * 255 + a / 2) / a))
                }
                i += 4
            }
        }
    }

    static func premultiply(_ buffer: inout [UInt8]) {
        buffer.withUnsafeMutableBufferPointer { p in
            var i = 0
            while i < p.count {
                let a = Int(p[i + 3])
                if a == 0 {
                    p[i] = 0; p[i + 1] = 0; p[i + 2] = 0
                } else if a != 255 {
                    p[i] = UInt8((Int(p[i]) * a + 127) / 255)
                    p[i + 1] = UInt8((Int(p[i + 1]) * a + 127) / 255)
                    p[i + 2] = UInt8((Int(p[i + 2]) * a + 127) / 255)
                }
                i += 4
            }
        }
    }
}