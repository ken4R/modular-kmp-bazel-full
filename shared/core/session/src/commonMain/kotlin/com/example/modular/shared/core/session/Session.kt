package com.example.modular.shared.core.session

/** The signed-in user. */
public data class Session(val userName: String)

/** Outcome of a sign-in attempt. A business failure is a value, not an exception. */
public sealed interface SignInResult {
    public data class Success(val session: Session) : SignInResult
    public data object InvalidCredentials : SignInResult
}
