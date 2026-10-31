import MeihuaCore
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// 工具页统一外框：可滚动、灰底、拖动收起键盘。
struct ToolScaffold<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
    }
}

/// 选素材：相册多选、文件多选（zip 默认解开）。
struct InputSection: View {
    let session: ToolSession
    var title: String = "素材"
    var allowPhotos: Bool = true
    var fileTypes: [UTType] = [.image, .zip]
    var expandZip: Bool = true
    var hint: String? = nil

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showImporter = false

    var body: some View {
        SectionCard(title) {
            HStack(spacing: 10) {
                if allowPhotos {
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 200, matching: .images,
                                 preferredItemEncoding: .current) {
                        Label("相册", systemImage: "photo.on.rectangle")
                    }
                }
                Button { showImporter = true } label: {
                    Label("文件", systemImage: "folder")
                }
                Spacer(minLength: 0)
                if !session.inputs.isEmpty {
                    Button("清空", role: .destructive) { session.clearInputs() }
                }
            }
            .buttonStyle(.bordered)
            if session.isLoading {
                ProgressView("正在读取…")
            }
            Text(summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let hint {
                Text(hint).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: fileTypes, allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): session.importFiles(urls, expandZip: expandZip)
            case .failure(let error): session.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            session.importPhotos(items)
            photoItems = []
        }
    }

    private var summary: String {
        let n = session.inputs.count
        guard n > 0 else { return "还没有选择素材" }
        let names = session.inputs.prefix(3).map(\.fileName).joined(separator: "、")
        return "已选 \(n) 个：\(names)" + (n > 3 ? " 等" : "")
    }
}

struct RunSection: View {
    let session: ToolSession
    var title: String = "开始处理"
    var disabled: Bool = false
    var requiresInputs: Bool = true
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: action) {
                HStack(spacing: 8) {
                    if session.isRunning { ProgressView().tint(.white) }
                    Text(session.isRunning ? "处理中 \(Int(session.progress * 100))%" : title).bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(disabled || session.isRunning || session.isLoading || (requiresInputs && session.inputs.isEmpty))
            if let error = session.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
    }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case png, jpg

    var id: String { rawValue }
    var title: String { self == .png ? "PNG 保留透明" : "JPG 体积小" }
    var imageFormat: ImageFormat { self == .png ? .png : .jpeg(quality: 0.92) }
}

extension Color {
    /// 取 sRGB 分量；超出 0–1 的扩展色域值会被夹住。
    var rgba8: RGBA8 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
        return RGBA8(r: c(r), g: c(g), b: c(b), a: c(a))
    }

    init(_ rgba: RGBA8) {
        self.init(.sRGB, red: Double(rgba.r) / 255, green: Double(rgba.g) / 255,
                  blue: Double(rgba.b) / 255, opacity: Double(rgba.a) / 255)
    }
}