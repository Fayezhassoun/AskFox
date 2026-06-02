import AskFoxCore
import Foundation

func assert(_ condition: Bool, _ name: String) {
    if condition {
        print("PASS \(name)")
    } else {
        print("FAIL \(name)")
        exit(1)
    }
}

let basicMarkdown = """
---
title: Test
---
# Top

Intro paragraph.

## Subsection

Body of the subsection with some text.

## Another

More body.
"""

let chunks = NoteChunker.chunk(markdown: basicMarkdown)

assert(chunks.count == 3, "chunkProducesThreeChunks")
assert(chunks[0].heading == "Top", "firstChunkHeadingIsTop")
assert(chunks[0].text.contains("Intro paragraph"), "firstChunkHasIntro")
assert(chunks[1].heading == "Top > Subsection", "secondChunkHasNestedHeading")
assert(chunks[2].heading == "Top > Another", "thirdChunkHasAnotherHeading")

let noHeadings = "Just a body with no headings at all."
let bare = NoteChunker.chunk(markdown: noHeadings)
assert(bare.count == 1 && bare[0].heading.isEmpty, "noHeadingsProducesSingleChunkWithEmptyHeading")

let longBody = String(repeating: "lorem ipsum dolor sit amet. ", count: 200)
let bigMarkdown = "# Big\n\n" + longBody
let bigChunks = NoteChunker.chunk(markdown: bigMarkdown)
assert(bigChunks.count >= 2, "largeSectionIsSplitIntoMultipleChunks")
for chunk in bigChunks {
    assert(chunk.text.count <= NoteChunker.maxChunkChars + 200, "noChunkExceedsMaxByMuch")
}

let frontmatterOnly = "---\nkey: value\n---\n# Real\n\nBody"
let stripped = NoteChunker.chunk(markdown: frontmatterOnly)
assert(stripped.count == 1 && stripped[0].text.contains("Body"), "frontmatterIsStripped")

let a: [Float] = [1, 0, 0]
let b: [Float] = [1, 0, 0]
let c: [Float] = [0, 1, 0]
let indexFixture = VectorIndex(model: "test", files: [
    "/a": StoredFile(mtime: 0, chunks: [StoredChunk(heading: "h1", text: "match", charOffset: 0, embedding: a)]),
    "/b": StoredFile(mtime: 0, chunks: [StoredChunk(heading: "h2", text: "miss",  charOffset: 0, embedding: c)])
])

let hits = VectorStore.search(indexFixture, queryEmbedding: b, topK: 2)
assert(hits.count == 2, "searchReturnsTopK")
assert(hits[0].path == "/a", "searchRanksClosestVectorFirst")
assert(hits[0].score > 0.99, "searchScoreIsCosineOne")
assert(hits[1].score < 0.01, "orthogonalVectorScoresZero")

print("All AskFox core checks passed")
