import Foundation

struct LyricsLine: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval?
    let text: String
    let isInstrumental: Bool

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval? = nil,
        text: String,
        isInstrumental: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.isInstrumental = isInstrumental
    }
}

struct LyricsDocument: Hashable, Sendable {
    let source: String
    let lines: [LyricsLine]
    let isSynced: Bool
}
