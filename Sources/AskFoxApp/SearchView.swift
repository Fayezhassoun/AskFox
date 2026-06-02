import AskFoxCore
import SwiftUI

struct SearchView: View {
    @ObservedObject var state: AppState
    let onClose: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 720, height: 520)
        .background(.regularMaterial)
        .onAppear { isFocused = true }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)

            TextField("Ask your vault…", text: $state.question)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium))
                .focused($isFocused)
                .onSubmit { state.ask() }

            if state.isAnswering {
                ProgressView().controlSize(.small)
            }

            Button {
                state.ask()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(state.isAnswering || state.question.isEmpty)
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        if let error = state.lastError {
            ScrollView {
                Text(error)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        } else if state.answer.isEmpty && !state.isAnswering {
            VStack(spacing: 8) {
                Image(systemName: "questionmark.bubble")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("Ask anything grounded in your vault.")
                    .foregroundStyle(.secondary)
                Text("Tip: ⌥⌘Space opens this from anywhere.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !state.answer.isEmpty {
                        Text(.init(state.answer))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !state.citations.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sources")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 2)

                            ForEach(Array(state.citations.enumerated()), id: \.offset) { idx, citation in
                                Button {
                                    state.openInObsidian(path: citation.path)
                                } label: {
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("[\(idx + 1)]")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(displayName(citation.path))
                                                .font(.callout)
                                                .lineLimit(1)
                                            if !citation.heading.isEmpty {
                                                Text(citation.heading)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Text(String(format: "%.2f", citation.score))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var footer: some View {
        HStack {
            if !state.indexStatus.isEmpty {
                Text(state.indexStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Vault: \(state.settings.vaultPath)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Reindex") {
                state.reindex()
            }
            .font(.caption)
            Button("Close") {
                onClose()
            }
            .font(.caption)
            .keyboardShortcut(.escape)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func displayName(_ path: String) -> String {
        let vault = state.settings.vaultURL.path
        if path.hasPrefix(vault) {
            var rel = String(path.dropFirst(vault.count))
            if rel.hasPrefix("/") { rel.removeFirst() }
            return rel
        }
        return (path as NSString).lastPathComponent
    }
}
