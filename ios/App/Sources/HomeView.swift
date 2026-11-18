import DesignSystem
import SwiftUI

/// Placeholder for what comes after login. It stays in the application until a real feature replaces it.
struct HomeView: View {

    let userName: String
    let onSignOut: () async -> Void

    @State private var isSigningOut = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Bonjour, \(userName)")
                .font(.title.bold())

            PrimaryButton("Se déconnecter", isLoading: isSigningOut) {
                isSigningOut = true
                Task { await onSignOut() }
            }
        }
        .padding(.horizontal, 24)
    }
}
