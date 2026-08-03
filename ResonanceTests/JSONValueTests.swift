import XCTest
@testable import Resonance

final class JSONValueTests: XCTestCase {
    func testRoundTripsObjectsAndArrays() throws {
        let payload: JSONValue = .object([
            "name": .string("Resonance"),
            "tags": .array([.string("music"), .string("iOS")]),
            "version": .number(0.1),
            "flag": .bool(true)
        ])
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded["name"]?.stringValue, "Resonance")
        XCTAssertEqual(decoded["tags"]?.arrayValue?.compactMap(\.stringValue), ["music", "iOS"])
        XCTAssertEqual(decoded["version"]?.doubleValue, 0.1)
        XCTAssertEqual(decoded["flag"]?.boolValue, true)
    }

    func testRecursivelyCollectsKeyedValues() {
        let value: JSONValue = .object([
            "outer": .object([
                "inner": .string("match"),
                "array": .array([.object(["inner": .string("second")])])
            ]),
            "inner": .string("top")
        ])
        XCTAssertEqual(value.values(forKey: "inner").compactMap(\.stringValue), ["match", "second", "top"])
    }
}
