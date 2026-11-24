package com.example.modular.feature.login

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.modular.shared.feature.login.LoginEvent
import com.example.modular.shared.feature.login.LoginViewModel
import kotlinx.coroutines.Dispatchers

/**
 * Entry point of the login feature: binds the shared [LoginViewModel] to [LoginScreen]
 * and hands its navigation intents to the application.
 */
@Composable
fun LoginRoute(
    viewModel: LoginViewModel,
    onSignedIn: (userName: String) -> Unit,
    onPasswordResetRequested: (email: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    // Collected without dispatch: a text field must see its new value before the next keystroke.
    val state by viewModel.state.collectAsStateWithLifecycle(context = Dispatchers.Main.immediate)

    val currentOnSignedIn by rememberUpdatedState(onSignedIn)
    val currentOnPasswordResetRequested by rememberUpdatedState(onPasswordResetRequested)
    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is LoginEvent.SignedIn -> currentOnSignedIn(event.userName)
                is LoginEvent.PasswordResetRequested -> currentOnPasswordResetRequested(event.email)
            }
        }
    }

    LoginScreen(
        state = state,
        onEmailChanged = viewModel::onEmailChanged,
        onPasswordChanged = viewModel::onPasswordChanged,
        onSubmit = viewModel::submit,
        onForgotPassword = viewModel::requestPasswordReset,
        modifier = modifier,
    )
}
