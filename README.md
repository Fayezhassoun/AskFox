# AskFox

> A local-first AI brain over your Obsidian vault. Spotlight-fast, citation-grounded, private.

AskFox is a tiny macOS menu-bar app that turns your Obsidian vault into a
queryable brain. Press `⌥⌘Space`, ask anything, and get an answer that
quotes — and links to — your actual notes. No cloud. No upload. Your
notes never leave your Mac.

## What it does

- **Spotlight for your brain.** Global hotkey opens a search field from
  anywhere on macOS. Ask a question, get an answer in under a second.
- **Citation-grounded.** Every answer links to the exact note and section
  it came from. Click a source → it opens in Obsidian.
- **Streaming responses.** Answers start painting tokens the moment the
  local model emits them. No dead air.
- **100% local.** Runs on top of [LM Studio](https://lmstudio.ai/) with
  any OpenAI-compatible chat + embedding model. Your notes stay on disk.
- **Built for big vaults.** Tested with 2,300+ notes / 250k+ lines.
  Vector search uses Apple's Accelerate framework — flat-O(n) via
  `vDSP`, no Python, no daemons.

## Why it exists

Cloud AI assistants can't see your notes, and uploading them feels
gross. AskFox keeps everything on your Mac, indexes your vault into
embeddings once, then answers questions by retrieving the right chunks
and asking your local model to reason over them. The result feels like
asking a very fast reader who has memorised your whole vault.

## How it works

```
You → ⌥⌘Space → "what did I decide about pricing last month?"
        ↓
  Embed query (local nomic-embed)
        ↓
  Cosine search over precomputed vault vectors (Accelerate/vDSP)
        ↓
  Top-K chunks + system prompt → LM Studio chat model
        ↓
  Tokens stream back → Sources appear as soon as retrieval finishes
        ↓
  Click [1] → Obsidian opens the source note
```

The hot path is:

1. **Index load + query embed run in parallel** — saves 100-300ms.
2. **Precomputed L2 norms + `vDSP_dotpr`** — search is single-pass SIMD.
3. **SSE streaming chat** — first word appears the moment the model
   emits it.
4. **In-memory LRU cache** — repeat questions return instantly.

## Requirements

1. **macOS 14+** on Apple Silicon (Intel works, untested).
2. **LM Studio** running locally with two models loaded:
   - A chat model — e.g. `google/gemma-4-e4b`
   - An embedding model — e.g. `text-embedding-nomic-embed-text-v1.5`
3. LM Studio's local server enabled (default: `http://localhost:1234`).
4. An **Obsidian vault** on disk. Default: `~/Documents/Fox`.

## Install

### Download the DMG

Grab `AskFox-0.2.0.dmg` from the latest release, open it, drag
**AskFox** to **Applications**. Launch from Spotlight or `/Applications`.

The app is ad-hoc signed, so first launch needs right-click → Open. For
distribution outside your Mac, sign with a real Developer ID.

### Build from source

```bash
git clone <repo>
cd AskFox
Scripts/build-app.sh       # → .build/AskFox.app
Scripts/make-dmg.sh        # → .build/AskFox-0.2.0.dmg
```

Or run the dev binary directly:

```bash
swift run AskFox
```

## First-time setup

1. Launch AskFox. The menu bar shows **✨🔍**.
2. Open the menu and confirm:
   - **LM Studio Endpoint** — `http://localhost:1234/v1`
   - **Chat Model** — id of your chat model
   - **Embedding Model** — id of your embedding model
   - **Vault** — path to your Obsidian vault
3. Click **Reindex Vault**. First run embeds every chunk; subsequent
   runs only touch changed files.
4. Press `⌥⌘Space` anywhere. Ask.

### Index from CLI (faster, headless)

```bash
ASKFOX_VAULT=~/Documents/Fox \
ASKFOX_CHAT_MODEL=google/gemma-4-e4b \
ASKFOX_EMBEDDING_MODEL=text-embedding-nomic-embed-text-v1.5 \
swift run AskFoxIndex
```

## Verify

```bash
swift run AskFoxCoreCheck     # unit tests
swift build                   # everything compiles
```

## Privacy

- No network calls except to your local LM Studio.
- No telemetry, no analytics, no crash reporting.
- The vault index lives in
  `~/Library/Application Support/AskFox/index.json`. Delete it to
  reset.

## Project layout

```
AskFox/
├── Sources/
│   ├── AskFoxCore/         # engine, vector store, LM Studio client
│   ├── AskFoxApp/          # menu-bar UI, hotkey, window
│   ├── AskFoxIndex/        # CLI reindex tool
│   └── AskFoxCoreCheck/    # unit tests
├── Scripts/
│   ├── build-app.sh        # .build/AskFox.app
│   └── make-dmg.sh         # .build/AskFox-<ver>.dmg
└── Package.swift
```

## License

Private. Built for Fayez.
