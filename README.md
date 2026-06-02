# AskFox

Spotlight-style menu-bar app that answers questions grounded in your
Obsidian vault. OpenAI embeddings + GPT for the answer. Citations
open the source note in Obsidian.

## Run from source

```bash
swift run AskFox
```

Set your OpenAI API key once (Settings → API Key, stored in macOS
Keychain), point at your vault path (default `~/Documents/Fox`),
then press **⌥⌘Space** anywhere to open the search window.

## First-time index

```bash
OPENAI_API_KEY=sk-... swift run AskFoxIndex
```

Indexes every `.md` file under the vault, chunks by heading, embeds
with `text-embedding-3-small`, and writes `~/Library/Application Support/AskFox/index.json`.

Re-running picks up new and changed files. ~$0.10 to index a
mid-size vault.

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
