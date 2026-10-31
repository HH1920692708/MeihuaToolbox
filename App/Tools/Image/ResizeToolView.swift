import MeihuaCore
import SwiftUI

/// 改尺寸。也是其他工具页的参照写法：ToolScaffold + InputSection + 选项 + RunSection + OutputSection，
/// 处理逻辑放在 session.run 的闭包里，只捕获值类型，不碰界面状态。
struct ResizeToolView: View {
    @State private var session = ToolSession()
    @State private var useDevices = true
    @State private var selected: Set<String> = ["6.9", "11xr"]
    @State private var width = 1080
    @State private var height = 1920
    @State private var mode: ResizeMode = .fill
    @State private var format: OutputFormat = .png

    var body: some View {
        ToolScaffold {
            InputSection(session: session)
            SectionCard("尺寸") {
                Picker("方式", selection: $useDevices) {
                    Text("按机型").tag(true)
                    Text("自定义").tag(false)
                }
                .pickerStyle(.segmented)
                if useDevices { devicePicker } else { customSize }
                Picker("缩放", selection: $mode) {
                    ForEach(ResizeMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("格式", selection: $format) {
                    ForEach(OutputFormat.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("选了多个机型时，每个机型一个子文件夹；11/XR 那档文件夹名是 11xr。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            RunSection(session: session, disabled: useDevices && selected.isEmpty) { run() }
            OutputSection(session: session, exportName: ToolID.resize.title)
        }
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(DevicePreset.all) { preset in
                Toggle(isOn: binding(for: preset.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(preset.title)  \(preset.size.description)")
                        Text(preset.models).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var customSize: some View {
        HStack {
            TextField("宽", value: $width, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Text("×")
            TextField("高", value: $height, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Text("像素").foregroundStyle(.secondary)
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { on in
                if on { selected.insert(id) } else { selected.remove(id) }
            }
        )
    }

    private func run() {
        let targets: [ResizeTarget]
        if useDevices {
            targets = DevicePreset.all
                .filter { selected.contains($0.id) }
                .map { ResizeTarget(folder: $0.folderName, size: $0.size) }
        } else {
            let size = PixelSize(width: width, height: height)
            guard size.isValid else {
                session.errorMessage = "宽高要在 1 到 16384 之间"
                return
            }
            targets = [ResizeTarget(folder: "", size: size)]
        }
        let scaleMode = mode
        let outFormat = format.imageFormat
        let useFolders = targets.count > 1
        session.run { inputs, progress in
            Batch.map(Batch.images(inputs), progress: progress) { item in
                let image = try ImageCodec.decode(item.data, name: item.fileName)
                return try targets.map { target in
                    let resized = try Render.resize(image, to: target.size, mode: scaleMode)
                    let path = FileItem.join(useFolders ? target.folder : "",
                                             item.replacingExtension(outFormat.fileExtension))
                    return FileItem(path: path, data: try ImageCodec.encode(resized, as: outFormat, name: item.fileName))
                }
            }
        }
    }
}

private struct ResizeTarget: Sendable {
    let folder: String
    let size: PixelSize
}