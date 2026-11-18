package com.example.modular.shared.feature.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.modular.shared.core.session.SessionRepository
import com.example.modular.shared.core.session.SignInResult
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Logic of the login screen, written once for Android and iOS.
 *
 * The screen reads [state], calls the functions below when the user acts,
 * and forwards [events] to the navigation of its application.
 */
public class LoginViewModel(
    private val sessions: SessionRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(LoginUiState())
    public val state: StateFlow<LoginUiState> = _state.asStateFlow()

    private val _events = Channel<LoginEvent>(Channel.BUFFERED)
    public val events: Flow<LoginEvent> = _events.receiveAsFlow()

    public fun onEmailChanged(email: String) {
        _state.update { it.copy(email = email, error = null) }
    }

    public fun onPasswordChanged(password: String) {
        _state.update { it.copy(password = password, error = null) }
    }

    /** Signs in with the current form. Does nothing while the form cannot be sent. */
    public fun submit() {
        val form = _state.value
        if (!form.canSubmit) return

        val email = form.email.trim()
        if (!isValidEmail(email)) {
            _state.update { it.copy(error = LoginError.InvalidEmail) }
            return
        }

        _state.update { it.copy(isSubmitting = true, error = null) }
        viewModelScope.launch {
            when (val result = sessions.signIn(email, form.password)) {
                is SignInResult.Success -> {
                    _state.update { it.copy(isSubmitting = false, password = "") }
                    _events.send(LoginEvent.SignedIn(result.session.userName))
                }

                SignInResult.InvalidCredentials -> {
                    _state.update { it.copy(isSubmitting = false, error = LoginError.InvalidCredentials) }
                }
            }
        }
    }

    public fun requestPasswordReset() {
        _events.trySend(LoginEvent.PasswordResetRequested(_state.value.email.trim()))
    }
}

/** Deliberately loose: the server is the authority on what an e-mail address is. */
internal fun isValidEmail(email: String): Boolean {
    val at = email.indexOf('@')
    return at > 0 && at == email.lastIndexOf('@') && at < email.length - 1 && email.none { it.isWhitespace() }
}
