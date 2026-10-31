import CoreGraphics
import XCTest
@testable import MeihuaCore

final class RenderTests: XCTestCase {
    private func solid(_ w: Int, _ h: Int, _ color: RGBA8) throws -> CGImage {
        try RGBABitmap(width: w, height: h, fill: color).makeImage()
    }

    func testBitmapRoundTripKeepsOpaquePixelsExact() throws {
        var bmp = RGBABitmap(width: 4, height: 3)
        bmp[0, 0] = RGBA8(r: 10, g: 20, b: 30)
        bmp[3, 2] = RGBA8(r: 250, g: 128, b: 1)
        let back = try RGBABitmap(bmp.makeImage())
        XCTAssertEqual(back.width, 4)
        XCTAssertEqual(back.height, 3)
        XCTAssertEqual(back[0, 0], RGBA8(r: 10, g: 20, b: 30))
        XCTAssertEqual(back[3, 2], RGBA8(r: 250, g: 128, b: 1))
        XCTAssertEqual(back[1, 1].a, 0)
    }

    func testBitmapRowZeroIsTopOfImage() throws {
        // 在 CG 坐标（左下原点）里把上半部分涂红；位图第 0 行应为红，最后一行透明。
        let ctx = try Render.makeContext(PixelSize(width: 2, height: 2))
        ctx.setFillColor(RGBA8(r: 255, g: 0, b: 0).cgColor)
        ctx.fill(CGRect(x: 0, y: 1, width: 2, height: 1))
        let bmp = try RGBABitmap(Render.image(from: ctx))
        XCTAssertEqual(bmp[0, 0], RGBA8(r: 255, g: 0, b: 0))
        XCTAssertEqual(bmp[0, 1].a, 0)
    }

    func testResizeFillProducesExactPixelSize() throws {
        let out = try Render.resize(solid(200, 100, .black), to: PixelSize(width: 828, height: 1792), mode: .fill)
        XCTAssertEqual(out.width, 828)
        XCTAssertEqual(out.height, 1792)
        let bmp = try RGBABitmap(out)
        XCTAssertEqual(bmp[0, 0].a, 255)
        XCTAssertEqual(bmp[827, 1791].a, 255)
    }

    func testResizeFitLeavesTransparentBars() throws {
        let out = try Render.resize(solid(200, 100, .black), to: PixelSize(width: 100, height: 100), mode: .fit)
        let bmp = try RGBABitmap(out)
        XCTAssertEqual(bmp[50, 2].a, 0, "上方应留透明")
        XCTAssertEqual(bmp[50, 50].a, 255)
        XCTAssertEqual(bmp[50, 97].a, 0, "下方应留透明")
    }

    func testDrawRectFitAndFill() {
        let src = PixelSize(width: 200, height: 100)
        let dst = PixelSize(width: 100, height: 100)
        XCTAssertEqual(Render.drawRect(source: src, target: dst, mode: .fit), CGRect(x: 0, y: 25, width: 100, height: 50))
        XCTAssertEqual(Render.drawRect(source: src, target: dst, mode: .fill), CGRect(x: -50, y: 0, width: 200, height: 100))
        XCTAssertEqual(Render.drawRect(source: src, target: dst, mode: .stretch), CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testCropUsesTopLeftOrigin() throws {
        var bmp = RGBABitmap(width: 4, height: 4)
        bmp[1, 0] = RGBA8(r: 0, g: 255, b: 0)
        let cropped = try Render.crop(bmp.makeImage(), x: 1, y: 0, width: 2, height: 2)
        let out = try RGBABitmap(cropped)
        XCTAssertEqual(out.width, 2)
        XCTAssertEqual(out[0, 0], RGBA8(r: 0, g: 255, b: 0))
    }

    func testRejectsInvalidSize() {
        XCTAssertThrowsError(try Render.makeContext(PixelSize(width: 0, height: 10)))
        XCTAssertThrowsError(try Render.makeContext(PixelSize(width: 20000, height: 10)))
    }

    func testPNGRoundTrip() throws {
        var bmp = RGBABitmap(width: 3, height: 3)
        bmp[1, 1] = RGBA8(r: 1, g: 2, b: 3)
        let data = try ImageCodec.encode(bmp.makeImage(), as: .png)
        XCTAssertEqual(ImageCodec.pixelSize(of: data), PixelSize(width: 3, height: 3))
        let back = try RGBABitmap(ImageCodec.decode(data))
        // 解码后的色彩空间对象可能不是同一个实例，绘制时允许 1 级误差
        let px = back[1, 1]
        XCTAssertEqual(px.a, 255)
        XCTAssertLessThanOrEqual(abs(Int(px.r) - 1), 1)
        XCTAssertLessThanOrEqual(abs(Int(px.g) - 2), 1)
        XCTAssertLessThanOrEqual(abs(Int(px.b) - 3), 1)
        XCTAssertEqual(back[0, 0].a, 0)
    }

    func testJPEGFlattensTransparencyToWhite() throws {
        let data = try ImageCodec.encode(RGBABitmap(width: 8, height: 8).makeImage(), as: .jpeg(quality: 0.9))
        let px = try RGBABitmap(ImageCodec.decode(data))[4, 4]
        XCTAssertEqual(px.a, 255)
        XCTAssertGreaterThan(px.r, 245)
        XCTAssertGreaterThan(px.g, 245)
        XCTAssertGreaterThan(px.b, 245)
    }

    func testDecodeGarbageThrows() {
        XCTAssertThrowsError(try ImageCodec.decode(Data([1, 2, 3]), name: "x.png")) { error in
            XCTAssertEqual(error as? CoreError, .decodeFailed("x.png"))
        }
    }
}

final class MiscTests: XCTestCase {
    func testHexParsing() {
        XCTAssertEqual(RGBA8(hex: "454e5a"), RGBA8(r: 0x45, g: 0x4e, b: 0x5a))
        XCTAssertEqual(RGBA8(hex: "#FF0000"), RGBA8(r: 255, g: 0, b: 0))
        XCTAssertEqual(RGBA8(hex: "9DFFFFFF"), RGBA8(r: 255, g: 255, b: 255, a: 0x9D))
        XCTAssertNil(RGBA8(hex: "12345"))
        XCTAssertNil(RGBA8(hex: "zzzzzz"))
        XCTAssertEqual(RGBA8(r: 0x45, g: 0x4e, b: 0x5a).hexString, "454e5a")
        XCTAssertEqual(RGBA8(r: 255, g: 255, b: 255, a: 0x9d).hexString, "9dffffff")
    }

    func testFileItemPathParts() {
        let item = FileItem(path: "icons/微信.PNG", data: Data())
        XCTAssertEqual(item.fileName, "微信.PNG")
        XCTAssertEqual(item.baseName, "微信")
        XCTAssertEqual(item.fileExtension, "png")
        XCTAssertEqual(item.directory, "icons")
        XCTAssertTrue(item.isImage)
        XCTAssertEqual(item.replacingExtension("jpg"), "icons/微信.jpg")
        XCTAssertEqual(FileItem(path: "a.png", data: Data()).directory, "")
    }

    func testBatchKeepsGoingAfterFailure() throws {
        let png = try ImageCodec.encode(RGBABitmap(width: 2, height: 2, fill: .black).makeImage(), as: .png)
        let inputs = [FileItem(path: "ok.png", data: png), FileItem(path: "bad.png", data: Data([0]))]
        var last = 0.0
        let result = Batch.map(inputs, progress: { last = $0 }) { item in
            let image = try ImageCodec.decode(item.data, name: item.fileName)
            return [FileItem(path: item.path, data: try ImageCodec.encode(image, as: .png))]
        }
        XCTAssertEqual(result.outputs.map(\.path), ["ok.png"])
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(result.failures[0].hasPrefix("bad.png"))
        XCTAssertEqual(last, 1.0)
    }

    func testBatchDeduplicatesOutputPaths() {
        let inputs = [FileItem(path: "a.png", data: Data()), FileItem(path: "b.png", data: Data())]
        let result = Batch.map(inputs) { _ in [FileItem(path: "same.png", data: Data())] }
        XCTAssertEqual(result.outputs.map(\.path), ["same.png", "same_2.png"])
    }

    func testDevicePresets() throws {
        let xr = try XCTUnwrap(DevicePreset.preset("11xr"))
        XCTAssertEqual(xr.size, PixelSize(width: 828, height: 1792))
        XCTAssertEqual(xr.scale, 2)
        XCTAssertEqual(xr.folderName, "11xr")
        XCTAssertEqual(DevicePreset.preset("6.9")?.folderName, "1320x2868")
        XCTAssertEqual(Set(DevicePreset.all.map(\.id)).count, DevicePreset.all.count)
        XCTAssertEqual(IconScale.x3.pixels, 180)
        XCTAssertEqual(IconScale.x2.pixels, 120)
    }
}