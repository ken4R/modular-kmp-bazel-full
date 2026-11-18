package com.example.modular.shared.feature.login

/**
 * Everything the login screen displays. Immutable: the ViewModel publishes a new instance
 * for every change, and both the Compose screen and the SwiftUI view render it as is.
 */
public data class LoginUiState(
    val email: String = "",
    val password: String = "",
    val isSubmitting: Boolean = false,
    val error: LoginError? = null,
) {
    /** True when the form can be sent. */
    public val canSubmit: Boolean
        get() = email.isNotBlank() && password.isNotEmpty() && !isSubmitting
}

/** Why the last attempt failed. Each platform maps a value to its own localized message. */
public enum class LoginError {
    InvalidEmail,
    InvalidCredentials,
}
