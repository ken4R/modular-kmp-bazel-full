import Login
import SharedKit
import SwiftUI

/// Root navigation of the prototype: two destinations and no navigation library yet.
/// Features report navigation intents, this is the only place that decides where they lead.
struct RootView: View {

    let graph: SharedGraph

    @State private var signedInUser: String?
    @State private var showsPasswordResetNotice = false

    var body: some View {
        if let signedInUser {
            HomeView(userName: signedInUser, onSignOut: signOut)
        } else {
            LoginView(
                viewModel: graph.loginViewModel(),
                onSignedIn: { signedInUser = $0 },
                onPasswordResetRequested: { _ in showsPasswordResetNotice = true }
            )
            .alert("Réinitialisation du mot de passe : écran à venir.", isPresented: $showsPasswordResetNotice) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func signOut() async {
        // A suspend function of the shared code is `async throws` in Swift. Here it can only
        // throw when the task is cancelled, and then there is nothing left to do.
        try? await graph.signOut()
        signedInUser = nil
    }
}
