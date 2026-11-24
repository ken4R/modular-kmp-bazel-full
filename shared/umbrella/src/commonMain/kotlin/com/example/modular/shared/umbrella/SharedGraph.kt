package com.example.modular.shared.umbrella

import com.example.modular.shared.core.session.InMemorySessionRepository
import com.example.modular.shared.core.session.SessionRepository
import com.example.modular.shared.feature.login.LoginViewModel

/**
 * Composition root of the shared code. Each application creates one instance at startup and asks
 * it for ViewModels: Compose and SwiftUI code never see repositories or other dependencies.
 *
 * Dependencies are wired by hand until the dependency injection library is chosen.
 */
public class SharedGraph {

    private val sessions: SessionRepository = InMemorySessionRepository()

    /**
     * Creates the ViewModel of the login screen. The caller gives it an owner:
     * `viewModel { graph.loginViewModel() }` in Compose, `Observed(graph.loginViewModel(), ...)` in SwiftUI.
     */
    public fun loginViewModel(): LoginViewModel = LoginViewModel(sessions)

    /** Closes the current session. Returns when the user is signed out. */
    public suspend fun signOut() {
        sessions.signOut()
    }
}
