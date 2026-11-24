package com.example.modular.shared.core.session

import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Prototype implementation: no network and no storage.
 * Any e-mail address signs in with the password [DEMO_PASSWORD]. [latency] stands for the network.
 */
public class InMemorySessionRepository(
    private val latency: Duration = 600.milliseconds,
) : SessionRepository {

    private val _session = MutableStateFlow<Session?>(null)
    override val session: StateFlow<Session?> = _session.asStateFlow()

    override suspend fun signIn(email: String, password: String): SignInResult {
        delay(latency)
        if (password != DEMO_PASSWORD) return SignInResult.InvalidCredentials
        val session = Session(userName = email.substringBefore('@'))
        _session.value = session
        return SignInResult.Success(session)
    }

    override suspend fun signOut() {
        delay(latency)
        _session.value = null
    }

    public companion object {
        public const val DEMO_PASSWORD: String = "kotlin"
    }
}
