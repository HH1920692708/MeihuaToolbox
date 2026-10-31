import Foundation
import XCTest
@testable import MeihuaCore

/// 手工拼一个「存储」方式的 zip，用来造 ZIPFoundation 写不出来的情况：非 UTF-8 文件名、`../` 路径。
enum RawZip {
    struct Entry {
        var name: [UInt8]
        var data: [UInt8]
        var utf8Flag: Bool
    }

    static func build(_ entries: [Entry]) -> Data {
        var out = [UInt8]()
        var central = [UInt8]()
        for e in entries {
            let offset = UInt32(out.count)
            let crc = crc32(e.data)
            let size = UInt32(e.data.count)
            let flags: UInt16 = e.utf8Flag ? 0x0800 : 0
            let nameLen = UInt16(e.name.count)
            // 本地文件头：签名、版本、标志、存储方式、时间、日期(1980-01-01)
            for chunk in [le32(0x04034b50), le16(20), le16(flags), le16(0), le16(0), le16(0x21),
                          le32(crc), le32(size), le32(size), le16(nameLen), le16(0)] {
                out.append(contentsOf: chunk)
            }
            out.append(contentsOf: e.name)
            out.append(contentsOf: e.data)
            // 中央目录：多了「制作版本」、注释长度、磁盘号、内外属性、本地头偏移
            for chunk in [le32(0x02014b50), le16(20), le16(20), le16(flags), le16(0), le16(0), le16(0x21),
                          le32(crc), le32(size), le32(size), le16(nameLen), le16(0), le16(0),
                          le16(0), le16(0), le32(0), le32(offset)] {
                central.append(contentsOf: chunk)
            }
            central.append(contentsOf: e.name)
        }
        let cdOffset = UInt32(out.count)
        let count = UInt16(entries.count)
        out.append(contentsOf: central)
        for chunk in [le32(0x06054b50), le16(0), le16(0), le16(count), le16(count),
                      le32(UInt32(central.count)), le32(cdOffset), le16(0)] {
            out.append(contentsOf: chunk)
        }
        return Data(out)
    }

    static func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }
    static func le32(_ v: UInt32) -> [UInt8] { (0..<4).map { UInt8((v >> (8 * $0)) & 0xFF) } }

    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for b in bytes {
            crc ^= UInt32(b)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return ~crc
    }
}

final class ZipCodecTests: XCTestCase {
    func testRoundTripKeepsChineseNamesAndContent() throws {
        let items = [
            FileItem(path: "图标/微信.png", data: Data("a".utf8)),
            FileItem(path: "图标/微信.png", data: Data("b".utf8)),
            FileItem(path: "empty.txt", data: Data())
        ]
        let back = try ZipCodec.extract(ZipCodec.archive(items))
        XCTAssertEqual(back.map(\.path), ["图标/微信.png", "图标/微信_2.png", "empty.txt"])
        XCTAssertEqual(back[0].data, Data("a".utf8))
        XCTAssertEqual(back[1].data, Data("b".utf8))
        XCTAssertEqual(back[2].data.count, 0)
    }

    func testArchiveHandlesSlicedData() throws {
        let whole = Data("0123456789".utf8)
        let slice = whole[3..<7]
        let back = try ZipCodec.extract(ZipCodec.archive([FileItem(path: "s.bin", data: slice)]))
        XCTAssertEqual(back.first?.data, Data("3456".utf8))
    }

    func testGBKFileNameFromWindowsZip() throws {
        // 「图标.png」的 GBK 字节，不带 UTF-8 标志位
        let name: [UInt8] = [0xCD, 0xBC, 0xB1, 0xEA] + Array(".png".utf8)
        let zip = RawZip.build([.init(name: name, data: Array("x".utf8), utf8Flag: false)])
        let back = try ZipCodec.extract(zip)
        XCTAssertEqual(back.map(\.path), ["图标.png"])
    }

    func testDropsTraversalJunkAndDirectories() throws {
        let zip = RawZip.build([
            .init(name: Array("../evil.png".utf8), data: [1], utf8Flag: true),
            .init(name: Array("a/../../evil2.png".utf8), data: [1], utf8Flag: true),
            .init(name: Array("__MACOSX/._a.png".utf8), data: [1], utf8Flag: true),
            .init(name: Array("dir/".utf8), data: [], utf8Flag: true),
            .init(name: Array("/abs/ok.png".utf8), data: [7], utf8Flag: true),
            .init(name: Array("win\\path.png".utf8), data: [8], utf8Flag: true)
        ])
        let back = try ZipCodec.extract(zip)
        XCTAssertEqual(back.map(\.path), ["abs/ok.png", "win/path.png"])
        XCTAssertEqual(back[0].data, Data([7]))
    }

    func testRejectsNonZip() {
        XCTAssertThrowsError(try ZipCodec.extract(Data("not a zip".utf8)))
    }

    func testSanitize() {
        XCTAssertEqual(ZipCodec.sanitize("./a//b.png"), "a/b.png")
        XCTAssertNil(ZipCodec.sanitize("a/../b.png"))
        XCTAssertNil(ZipCodec.sanitize("///"))
    }
}