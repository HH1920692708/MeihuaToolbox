import Foundation
import XCTest
@testable import MeihuaCore

final class IniDocumentTests: XCTestCase {
    private let sample = "[GLOBAL]\r\nSTYLE_NUM=2\r\n\r\n[STYLE1]\r\n; 注释\r\nNM_COLOR=454e5a\r\nSHOW=q\r\n\r\n[STYLE2]\nHL_COLOR = 9DFFFFFF \nKEY=a\u{2028}b\n"

    func testReadValuesCaseInsensitively() throws {
        let doc = IniDocument(text: sample)
        XCTAssertEqual(doc.sections, ["GLOBAL", "STYLE1", "STYLE2"])
        XCTAssertEqual(doc.value("style_num", in: "global"), "2")
        XCTAssertEqual(doc.value("NM_COLOR", in: "STYLE1"), "454e5a")
        XCTAssertEqual(doc.value("HL_COLOR", in: "STYLE2"), "9DFFFFFF")
        XCTAssertEqual(doc.value("KEY", in: "STYLE2"), "a\u{2028}b", "U+2028 要原样保留")
        XCTAssertNil(doc.value("NM_COLOR", in: "STYLE2"))
        XCTAssertEqual(doc.entries(in: "STYLE1").map { $0.key }, ["NM_COLOR", "SHOW"])
    }

    func testUntouchedDocumentRoundTripsByteForByte() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data(sample.utf8)
        let doc = try IniDocument(data: data)
        XCTAssertEqual(doc.encoding, .utf8BOM)
        XCTAssertEqual(doc.data(), data)
    }

    func testSetValueOnlyChangesThatLine() throws {
        var doc = IniDocument(text: sample)
        doc.setValue("ff0000", for: "nm_color", in: "STYLE1")
        let expected = sample.replacingOccurrences(of: "NM_COLOR=454e5a", with: "NM_COLOR=ff0000")
        XCTAssertEqual(doc.text, expected)
    }

    func testSetValueAppendsInsideSectionBeforeBlankLine() {
        var doc = IniDocument(text: sample)
        doc.setValue("1", for: "NEW", in: "STYLE1")
        XCTAssertTrue(doc.text.contains("SHOW=q\r\nNEW=1\r\n\r\n[STYLE2]"))
        doc.setValue("x", for: "A", in: "MISSING")
        XCTAssertEqual(doc.value("A", in: "MISSING"), "x")
        XCTAssertEqual(doc.sections.last, "MISSING")
    }

    func testRemoveSectionAndValue() {
        var doc = IniDocument(text: sample)
        XCTAssertTrue(doc.removeSection("STYLE1"))
        XCTAssertEqual(doc.sections, ["GLOBAL", "STYLE2"])
        XCTAssertTrue(doc.removeValue("KEY", in: "STYLE2"))
        XCTAssertNil(doc.value("KEY", in: "STYLE2"))
        XCTAssertFalse(doc.removeSection("NOPE"))
    }

    func testGB18030FallbackAndRoundTrip() throws {
        let text = "[INFO]\r\nName=森林\r\n"
        let gbData = try XCTUnwrap(text.data(using: ZipCodec.gb18030))
        let doc = try IniDocument(data: gbData)
        XCTAssertEqual(doc.encoding, .gb18030)
        XCTAssertEqual(doc.value("Name", in: "INFO"), "森林")
        XCTAssertEqual(doc.data(), gbData)
    }

    func testLoneCRAndMissingFinalNewline() {
        let doc = IniDocument(text: "[A]\rX=1\r\nY=2")
        XCTAssertEqual(doc.value("X", in: "A"), "1")
        XCTAssertEqual(doc.value("Y", in: "A"), "2")
        XCTAssertEqual(doc.text, "[A]\rX=1\r\nY=2")
    }
}