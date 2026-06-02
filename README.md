# AskFox

Spotlight-style menu-bar app that answers questions grounded in your
Obsidian vault. Runs entirely on your Mac via an LM Studio
OpenAI-compatible server. Citations open the source note in Obsidian.

## Requirements

1. **LM Studio** running with two models loaded:
   - A chat model, e.g. `google/gemma-4-e4b`
   - An embedding model, e.g. `text-embedding-nomic-embed-text-v1.5`
2. LM Studio's local server enabled at `http://localhost:1234`.

## Run from source

```bash
swift run AskFox
```

Open the menu (✨🔍 in the top bar) and confirm:
- **LM Studio Endpoint** — `http://localhost:1234/v1` (default)
- **Chat Model** — id of the chat model you loaded in LM Studio
- **Embedding Model** — id of the embedding model you loaded
- **Vault** — defaults to `~/Documents/Fox`

Then **Reindex Vault**, then press **⌥⌘Space** anywhere to ask.

## First-time index (CLI)

```bash
ASKFOX_VAULT=~/Documents/Fox \
ASKFOX_CHAT_MODEL=google/gemma-4-e4b \
ASKFOX_EMBEDDING_MODEL=text-embedding-nomic-embed-text-v1.5 \
swift run AskFoxIndex
```

## Verify

```bash
swift run AskFoxCoreCheck
swift build
```

## Build an installable .app and DMG

```bash
Scripts/build-app.sh
Scripts/make-dmg.sh
```
