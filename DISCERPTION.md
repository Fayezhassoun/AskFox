# AskFox — Discerption

## One-liner

A local-first AI brain for your Obsidian vault. Spotlight-fast, citation-grounded, private.

## Short (≤ 140 chars)

AskFox turns your Obsidian vault into a queryable brain. Press ⌥⌘Space, ask anything, get an answer with clickable citations — all on-device via LM Studio.

## Elevator (1 paragraph)

AskFox is a tiny macOS menu-bar app that lets you ask questions in plain English and get answers grounded in your own Obsidian notes. It runs entirely on your Mac through LM Studio — no cloud, no uploads, no telemetry. Every answer cites the exact note and section it came from, and a single click opens the source in Obsidian. Built for vaults of any size, from a hundred notes to thousands, with vector search powered by Apple's Accelerate framework and streaming responses that feel instant. If you think with your Obsidian vault, AskFox is the fastest way to ask it a question.

## Long (release-notes style)

### What is AskFox?

Most AI assistants don't know what you know. AskFox does — because it reads what you write.

AskFox is a native macOS app that lives in your menu bar and indexes your Obsidian vault into a local vector index. Press `⌥⌘Space` from anywhere on your Mac, type a question in plain English, and AskFox retrieves the most relevant chunks from your notes, hands them to a local chat model running in LM Studio, and streams back an answer with bracketed citations like `[1]`, `[2]`. Click any citation and the source note opens in Obsidian.

Everything stays on your machine. The chat model is local. The embedding model is local. The index is a single JSON file in `~/Library/Application Support/AskFox/`. No data leaves your Mac.

### Why you'd want it

- **You think in Obsidian.** Daily notes, project logs, reading notes, decisions, journal entries. Your vault is your second brain — but searching it is keyword-bound, and asking it a *question* is impossible.
- **Cloud AI can't see your notes.** ChatGPT and friends don't have access to your private knowledge. Uploading your vault feels gross.
- **Local AI is finally good enough.** Models like Gemma 3, Qwen 2.5, and Llama 3 run on a MacBook. Nomic Embed v1.5 gives you production-grade retrieval in 768 dimensions.

### What's in v0.2.0

- **Streaming responses.** Tokens appear the moment the model emits them. No more staring at a spinner for 5 seconds.
- **Accelerate-backed vector search.** Precomputed L2 norms + `vDSP_dotpr` SIMD kernel. Comfortable up to ~100k chunks. Your 2,300-note vault searches in a single fused pass.
- **Parallel hot path.** Index load and query embed run concurrently. Saves 100-300ms per query.
- **LRU answer cache.** Repeat a question, get an instant answer.
- **Pre-flight Sources panel.** Citations appear before the answer finishes generating.
- **Ad-hoc signed `.app` + DMG installer.** Drag to Applications, done.

### What it looks like

```
┌─ ✨🔍 AskFox ─────────────────────────────────────┐
│                                                   │
│  🔍 What did I decide about pricing in May?       │
│                                       [ ⏎ Ask ]  │
├───────────────────────────────────────────────────┤
│                                                   │
│  You decided to move to a usage-based tier for    │
│  SMB customers in mid-May, and to grandfather     │
│  existing annual contracts [1]. The rationale     │
│  was churn pressure on the $99/mo plan [2].       │
│                                                   │
│  Sources                                          │
│  [1] 05-12 Daily Note          § Pricing decision │
│  [2] 05-18 Daily Note          § Churn analysis   │
│                                                   │
├───────────────────────────────────────────────────┤
│  Vault: ~/Documents/Fox       [ Reindex ] [Close] │
└───────────────────────────────────────────────────┘
```

### Tech, briefly

- **Swift 6.0** package, macOS 14+, Apple Silicon native.
- **SwiftUI** UI, **AppKit** menu-bar + global hotkey.
- **Accelerate / vDSP** for vector search.
- **URLSession async bytes** for SSE streaming chat.
- **LM Studio** OpenAI-compatible API for chat + embeddings.
- Zero third-party dependencies.

### Requirements

- macOS 14+ on Apple Silicon.
- LM Studio running locally with a chat model and an embedding model loaded.
- An Obsidian vault on disk.

### Get it

- **DMG**: `AskFox-0.2.0.dmg` in the releases panel.
- **Source**: `git clone` and `Scripts/build-app.sh`.
- **Verify**: `swift run AskFoxCoreCheck`.

### Privacy

No network calls except to your local LM Studio. No telemetry. No analytics. No crash reports. The index is a single JSON file you can read, delete, or back up like any other.

### Roadmap

- Multi-vault support.
- File ingestion beyond Markdown (PDFs, images via OCR).
- Re-ranking with a cross-encoder for better retrieval quality.
- Conversation memory — ask follow-ups that remember what you asked before.
- AppleScript / Shortcuts integration.

### Built by

Fayez Hassoun. Because the best AI is the one that knows what you know.
