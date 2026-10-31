import SwiftUI

struct HomeView: View {
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    ForEach(ToolCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.title)
                                .font(.headline)
                                .padding(.horizontal, 4)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(ToolID.allCases.filter { $0.category == category }) { tool in
                                    NavigationLink(value: tool) {
                                        ToolCard(tool: tool)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Text("所有处理都在本机完成，不上传任何文件。存到文件的结果在「文件」App › 我的 iPhone › 美化工具箱 › 输出。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("美化工具箱")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ToolID.self) { tool in
                ToolRouter(tool: tool)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("美化工具箱")
                .font(.title2.bold())
            Text("图标、气泡、背景、键盘皮肤、切图，一个 App 搞定")
                .font(.subheadline)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.header, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ToolCard: View {
    let tool: ToolID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: tool.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tool.category.tint)
                .frame(width: 40, height: 40)
                .background(tool.category.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
            Text(tool.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(tool.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct ToolRouter: View {
    let tool: ToolID

    var body: some View {
        content
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch tool {
        case .resize: ResizeToolView()
        case .removeBackground: RemoveBackgroundToolView()
        case .watermark: WatermarkToolView()
        case .darkMark: DarkMarkToolView()
        case .iconPack: IconPackToolView()
        case .iconMatch: IconMatchToolView()
        case .iconCustomMatch: IconCustomMatchToolView()
        case .iconRecolor: IconRecolorToolView()
        case .iconBatchRecolor: IconBatchRecolorToolView()
        case .gridSlice: GridSliceToolView()
        case .spriteSlice: SpriteSliceToolView()
        case .keyboardTiles: KeyboardTilesToolView()
        case .redPacketBubble: RedPacketBubbleToolView()
        case .backgroundPack: BackgroundPackToolView()
        case .keyboardTopBar: KeyboardTopBarToolView()
        case .keyboardRecolor: KeyboardRecolorToolView()
        case .skinConvert: SkinConvertToolView()
        }
    }
}

/// 还没实现的工具先显示这个，避免首页点进去是空白。
struct ToolPlaceholder: View {
    let tool: ToolID

    var body: some View {
        ContentUnavailableView(tool.title, systemImage: tool.symbol, description: Text("这个工具还在开发中。"))
    }
}