package com.example.modular.shared.feature.login

/**
 * Navigation intents of the login feature. They are delivered once, in order.
 * The shared code says what happened, each application decides where to go.
 */
public sealed interface LoginEvent {

    /** The user is signed in: leave the login screen. */
    public data class SignedIn(val userName: String) : LoginEvent

    /** The user asked to reset the password of [email], which may be blank. */
    public data class PasswordResetRequested(val email: String) : LoginEvent
}
