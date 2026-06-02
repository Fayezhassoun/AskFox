import Foundation

public struct NoteChunk: Codable, Sendable, Equatable {
    public let heading: String
    public let text: String
    public let charOffset: Int

    public init(heading: String, text: String, charOffset: Int) {
        self.heading = heading
        self.text = text
        self.charOffset = charOffset
    }
}

public enum NoteChunker {
    public static let targetChunkChars = 1500
    public static let maxChunkChars = 2400

    public static func chunk(markdown raw: String) -> [NoteChunk] {
        let body = stripFrontmatter(raw)
        var chunks: [NoteChunk] = []
        var headingStack: [String] = []
        var currentBuffer = ""
        var currentOffset = 0
        var bufferStart = 0

        func flush() {
            let trimmed = currentBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                currentBuffer = ""
                bufferStart = currentOffset
                return
            }
            let heading = headingStack.joined(separator: " > ")
            for piece in splitIfLarge(trimmed) {
                chunks.append(NoteChunk(heading: heading, text: piece, charOffset: bufferStart))
            }
            currentBuffer = ""
            bufferStart = currentOffset
        }

        var cursor = body.startIndex
        while cursor < body.endIndex {
            let lineEnd = body[cursor...].firstIndex(of: "\n") ?? body.endIndex
            let line = String(body[cursor..<lineEnd])
            let lineLength = body.distance(from: cursor, to: lineEnd) + (lineEnd < body.endIndex ? 1 : 0)

            if let heading = parseHeading(line) {
                flush()
                while headingStack.count >= heading.level {
                    headingStack.removeLast()
                }
                while headingStack.count < heading.level - 1 {
                    headingStack.append("")
                }
                headingStack.append(heading.text)
            } else {
                if currentBuffer.count + line.count + 1 > maxChunkChars {
                    flush()
                }
                if !currentBuffer.isEmpty {
                    currentBuffer.append("\n")
                }
                currentBuffer.append(line)
            }

            currentOffset += lineLength
            cursor = lineEnd < body.endIndex ? body.index(after: lineEnd) : body.endIndex
        }

        flush()
        return chunks
    }

    private static func splitIfLarge(_ text: String) -> [String] {
        guard text.count > maxChunkChars else { return [text] }

        let paragraphs = text.components(separatedBy: "\n\n")
        let units: [String]
        if paragraphs.count > 1 {
            units = paragraphs
        } else if let sentenceUnits = sentenceSplit(text), sentenceUnits.count > 1 {
            units = sentenceUnits
        } else {
            return hardSplit(text)
        }

        var result: [String] = []
        var buffer = ""
        for unit in units {
            if unit.count > maxChunkChars {
                if !buffer.isEmpty {
                    result.append(buffer)
                    buffer = ""
                }
                result.append(contentsOf: hardSplit(unit))
                continue
            }

            let candidate = buffer.isEmpty ? unit : buffer + "\n\n" + unit
            if candidate.count > targetChunkChars && !buffer.isEmpty {
                result.append(buffer)
                buffer = unit
            } else {
                buffer = candidate
            }
        }
        if !buffer.isEmpty {
            result.append(buffer)
        }
        return result
    }

    private static func sentenceSplit(_ text: String) -> [String]? {
        let sentences = text.components(separatedBy: ". ")
        guard sentences.count > 1 else { return nil }
        return sentences.enumerated().map { idx, piece in
            idx < sentences.count - 1 ? piece + ". " : piece
        }
    }

    private static func hardSplit(_ text: String) -> [String] {
        var result: [String] = []
        var remaining = Substring(text)
        while remaining.count > targetChunkChars {
            let cut = remaining.index(remaining.startIndex, offsetBy: targetChunkChars)
            result.append(String(remaining[..<cut]))
            remaining = remaining[cut...]
        }
        if !remaining.isEmpty {
            result.append(String(remaining))
        }
        return result
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        var index = line.startIndex
        while index < line.endIndex && line[index] == "#" && level < 6 {
            level += 1
            index = line.index(after: index)
        }
        guard level > 0, index < line.endIndex, line[index] == " " else {
            return nil
        }
        let text = line[line.index(after: index)...].trimmingCharacters(in: .whitespaces)
        return (level, text.isEmpty ? "(untitled)" : text)
    }

    private static func stripFrontmatter(_ markdown: String) -> String {
        guard markdown.hasPrefix("---\n") else { return markdown }
        let afterOpen = markdown.index(markdown.startIndex, offsetBy: 4)
        guard let closeRange = markdown.range(of: "\n---\n", range: afterOpen..<markdown.endIndex) else {
            return markdown
        }
        return String(markdown[closeRange.upperBound...])
    }
}
