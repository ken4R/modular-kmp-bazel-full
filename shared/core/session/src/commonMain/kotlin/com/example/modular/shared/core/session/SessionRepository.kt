package com.example.modular.shared.core.session

import kotlinx.coroutines.flow.StateFlow

/** Owns the session of the current user. Features depend on this interface, never on an implementation. */
public interface SessionRepository {

    /** The current session, or `null` when nobody is signed in. */
    public val session: StateFlow<Session?>

    public suspend fun signIn(email: String, password: String): SignInResult

    public suspend fun signOut()
}
