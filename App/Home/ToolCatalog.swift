import SwiftUI

enum Theme {
    static let accent = Color(red: 0.40, green: 0.33, blue: 0.90)
    static let header = LinearGradient(
        colors: [Color(red: 0.42, green: 0.35, blue: 0.96), Color(red: 0.94, green: 0.43, blue: 0.62)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum ToolCategory: String, CaseIterable, Identifiable {
    case image, icon, slice, bubble, keyboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: return "图片"
        case .icon: return "图标"
        case .slice: return "切图"
        case .bubble: return "气泡与背景"
        case .keyboard: return "键盘皮肤（百度 iOS）"
        }
    }

    var tint: Color {
        switch self {
        case .image: return .teal
        case .icon: return .indigo
        case .slice: return .orange
        case .bubble: return .pink
        case .keyboard: return .blue
        }
    }
}

/// 首页上的全部工具。新增工具先在这里加一项，再到 ToolRouter 里接上页面。
enum ToolID: String, CaseIterable, Identifiable, Hashable {
    case resize, removeBackground, watermark, darkMark
    case iconPack, iconMatch, iconCustomMatch, iconRecolor, iconBatchRecolor
    case gridSlice, spriteSlice, keyboardTiles
    case redPacketBubble, backgroundPack
    case keyboardTopBar, keyboardRecolor, skinConvert

    var id: String { rawValue }

    var category: ToolCategory {
        switch self {
        case .resize, .removeBackground, .watermark, .darkMark: return .image
        case .iconPack, .iconMatch, .iconCustomMatch, .iconRecolor, .iconBatchRecolor: return .icon
        case .gridSlice, .spriteSlice, .keyboardTiles: return .slice
        case .redPacketBubble, .backgroundPack: return .bubble
        case .keyboardTopBar, .keyboardRecolor, .skinConvert: return .keyboard
        }
    }

    var title: String {
        switch self {
        case .resize: return "改尺寸"
        case .removeBackground: return "去除背景"
        case .watermark: return "批量水印"
        case .darkMark: return "暗标打标"
        case .iconPack: return "一键图标配套"
        case .iconMatch: return "一键图标对位"
        case .iconCustomMatch: return "自定义对标"
        case .iconRecolor: return "图标改色"
        case .iconBatchRecolor: return "图标批量改色"
        case .gridSlice: return "素材切割"
        case .spriteSlice: return "精灵图切割"
        case .keyboardTiles: return "键盘图片处理"
        case .redPacketBubble: return "红包气泡"
        case .backgroundPack: return "一键背景配套"
        case .keyboardTopBar: return "输入法顶栏"
        case .keyboardRecolor: return "皮肤改色"
        case .skinConvert: return "皮肤系统转换"
        }
    }

    var subtitle: String {
        switch self {
        case .resize: return "自定义宽高或按机型出图，含 11xr"
        case .removeBackground: return "点选要去掉的颜色，或自动抠主体"
        case .watermark: return "文字水印，可平铺，支持 zip"
        case .darkMark: return "写入看不见的标记，并能读出查询"
        case .iconPack: return "生成全局图标包，含 11xr"
        case .iconMatch: return "按 App 名自动改成标准命名"
        case .iconCustomMatch: return "上传命名表，批量改名"
        case .iconRecolor: return "单张图标换成指定颜色"
        case .iconBatchRecolor: return "上传 zip，批量换色"
        case .gridSlice: return "按网格或透明区域切图，支持 zip"
        case .spriteSlice: return "按 CSS 坐标切出每张小图"
        case .keyboardTiles: return "按切片表分割或拼接键盘素材"
        case .redPacketBubble: return "气泡九宫格标注，批量出图"
        case .backgroundPack: return "一张背景出全机型，含 11xr"
        case .keyboardTopBar: return "替换百度 iOS 皮肤的顶栏"
        case .keyboardRecolor: return "批量改皮肤的文字与边框颜色"
        case .skinConvert: return "百度安卓 .bds 与 iOS .bdi 互转"
        }
    }

    var symbol: String {
        switch self {
        case .resize: return "arrow.up.left.and.arrow.down.right"
        case .removeBackground: return "eraser"
        case .watermark: return "drop"
        case .darkMark: return "seal"
        case .iconPack: return "square.grid.3x3.fill"
        case .iconMatch: return "arrow.triangle.2.circlepath"
        case .iconCustomMatch: return "list.bullet.rectangle"
        case .iconRecolor: return "paintpalette"
        case .iconBatchRecolor: return "paintbrush"
        case .gridSlice: return "scissors"
        case .spriteSlice: return "square.split.2x2"
        case .keyboardTiles: return "rectangle.split.3x1"
        case .redPacketBubble: return "bubble.left.and.bubble.right"
        case .backgroundPack: return "photo"
        case .keyboardTopBar: return "keyboard"
        case .keyboardRecolor: return "drop.halffull"
        case .skinConvert: return "arrow.left.arrow.right"
        }
    }
}