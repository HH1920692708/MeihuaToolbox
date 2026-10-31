import Foundation

/// 机型像素尺寸。来源：https://www.ios-resolution.com/ 的 Physical Width/Height 与 Scale Factor 列。
public struct DevicePreset: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let models: String
    public let size: PixelSize
    public let scale: Int

    /// 输出子目录名。iPhone 11 / XR 这档用美化圈的叫法「11xr」。
    public var folderName: String { id == "11xr" ? "11xr" : "\(size.width)x\(size.height)" }

    public static let all: [DevicePreset] = [
        DevicePreset(id: "6.9", title: "6.9 寸", models: "16/17/18 Pro Max", size: .init(width: 1320, height: 2868), scale: 3),
        DevicePreset(id: "6.7", title: "6.7 寸", models: "14 Pro Max/15 Plus/15 Pro Max/16 Plus", size: .init(width: 1290, height: 2796), scale: 3),
        DevicePreset(id: "air", title: "Air", models: "iPhone Air", size: .init(width: 1260, height: 2736), scale: 3),
        DevicePreset(id: "6.3", title: "6.3 寸", models: "16 Pro/17/17 Pro/18 Pro", size: .init(width: 1206, height: 2622), scale: 3),
        DevicePreset(id: "6.1", title: "6.1 寸", models: "14 Pro/15/15 Pro/16", size: .init(width: 1179, height: 2556), scale: 3),
        DevicePreset(id: "6.1old", title: "6.1 寸旧款", models: "12/13/14/16e/17e", size: .init(width: 1170, height: 2532), scale: 3),
        DevicePreset(id: "6.7old", title: "6.7 寸旧款", models: "12/13 Pro Max/14 Plus", size: .init(width: 1284, height: 2778), scale: 3),
        DevicePreset(id: "xsmax", title: "XS Max", models: "XS Max/11 Pro Max", size: .init(width: 1242, height: 2688), scale: 3),
        DevicePreset(id: "x", title: "X", models: "X/XS/11 Pro", size: .init(width: 1125, height: 2436), scale: 3),
        DevicePreset(id: "mini", title: "mini", models: "12 mini/13 mini", size: .init(width: 1080, height: 2340), scale: 3),
        DevicePreset(id: "11xr", title: "11/XR", models: "iPhone 11/XR", size: .init(width: 828, height: 1792), scale: 2),
        DevicePreset(id: "plus", title: "Plus", models: "6-8 Plus", size: .init(width: 1080, height: 1920), scale: 3),
        DevicePreset(id: "se", title: "SE/8", models: "6-8/SE 2-3", size: .init(width: 750, height: 1334), scale: 2)
    ]

    public static func preset(_ id: String) -> DevicePreset? { all.first { $0.id == id } }
}

/// 主屏图标像素尺寸：60pt × 倍率。
public enum IconScale: Int, Sendable, CaseIterable, Identifiable {
    case x3 = 3
    case x2 = 2

    public var id: Int { rawValue }
    public var pixels: Int { 60 * rawValue }
    public var suffix: String { "@\(rawValue)x" }
}