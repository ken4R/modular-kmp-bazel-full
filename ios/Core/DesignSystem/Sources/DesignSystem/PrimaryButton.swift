import SwiftUI

/// Main action of a screen. While `isLoading`, it shows a progress indicator and ignores taps.
public struct PrimaryButton: View {

    private let title: String
    private let isLoading: Bool
    private let action: () -> Void

    public init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                // The title keeps its place, so the button has the same size while loading.
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Se connecter") {}
        PrimaryButton("Se connecter", isLoading: true) {}
    }
    .padding()
}
