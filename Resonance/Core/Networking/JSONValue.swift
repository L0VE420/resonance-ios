import Foundation

enum JSONValue: Codable, Hashable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }

    subscript(index: Int) -> JSONValue? {
        guard case .array(let array) = self, array.indices.contains(index) else { return nil }
        return array[index]
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        switch self {
        case .string(let value): value
        case .number(let value): String(value)
        default: nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): value
        case .string(let value): Double(value)
        default: nil
        }
    }

    func values(forKey key: String) -> [JSONValue] {
        var matches: [JSONValue] = []
        collectValues(forKey: key, into: &matches)
        return matches
    }

    func firstString(forKey key: String) -> String? {
        values(forKey: key).compactMap(\.stringValue).first
    }

    func text() -> String? {
        if let simpleText = self["simpleText"]?.stringValue {
            return simpleText
        }
        if let runs = self["runs"]?.arrayValue {
            let value = runs.compactMap { $0["text"]?.stringValue }.joined()
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private func collectValues(forKey key: String, into values: inout [JSONValue]) {
        switch self {
        case .object(let object):
            for (candidateKey, value) in object {
                if candidateKey == key { values.append(value) }
                value.collectValues(forKey: key, into: &values)
            }
        case .array(let array):
            for value in array {
                value.collectValues(forKey: key, into: &values)
            }
        default:
            break
        }
    }
}

extension JSONValue {
    static func object(_ values: [String: JSONValue?]) -> JSONValue {
        .object(values.compactMapValues { $0 })
    }

    static func strings(_ values: [String]) -> JSONValue {
        .array(values.map(JSONValue.string))
    }
}
