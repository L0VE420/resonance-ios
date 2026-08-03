import SwiftUI

struct AsyncStateView<Value, Content: View>: View {
    enum Phase { case idle, loading, loaded(Value), error(String) }

    let phase: Phase
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch phase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let value):
            content(value)
        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
