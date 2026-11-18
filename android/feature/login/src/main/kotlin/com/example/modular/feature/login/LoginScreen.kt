package com.example.modular.feature.login

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.modular.core.designsystem.ModularTheme
import com.example.modular.core.designsystem.PrimaryButton
import com.example.modular.shared.feature.login.LoginError
import com.example.modular.shared.feature.login.LoginUiState

/** The login form. It only renders [state] and reports what the user does: no logic lives here. */
@Composable
fun LoginScreen(
    state: LoginUiState,
    onEmailChanged: (String) -> Unit,
    onPasswordChanged: (String) -> Unit,
    onSubmit: () -> Unit,
    onForgotPassword: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(modifier = modifier) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.login_title),
                style = MaterialTheme.typography.headlineMedium,
            )
            OutlinedTextField(
                value = state.email,
                onValueChange = onEmailChanged,
                label = { Text(stringResource(R.string.login_email)) },
                singleLine = true,
                enabled = !state.isSubmitting,
                isError = state.error == LoginError.InvalidEmail,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = state.password,
                onValueChange = onPasswordChanged,
                label = { Text(stringResource(R.string.login_password)) },
                singleLine = true,
                enabled = !state.isSubmitting,
                isError = state.error == LoginError.InvalidCredentials,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { onSubmit() }),
                modifier = Modifier.fillMaxWidth(),
            )
            state.error?.let { error ->
                Text(
                    text = stringResource(error.messageRes),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            PrimaryButton(
                text = stringResource(R.string.login_submit),
                onClick = onSubmit,
                enabled = state.canSubmit,
                loading = state.isSubmitting,
            )
            TextButton(onClick = onForgotPassword, enabled = !state.isSubmitting) {
                Text(stringResource(R.string.login_forgot_password))
            }
            Text(
                text = stringResource(R.string.login_demo_hint),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** Wording is a platform concern: the shared code only says which error happened. */
private val LoginError.messageRes: Int
    get() = when (this) {
        LoginError.InvalidEmail -> R.string.login_error_invalid_email
        LoginError.InvalidCredentials -> R.string.login_error_invalid_credentials
    }

@Preview(showBackground = true)
@Composable
private fun LoginScreenPreview() {
    ModularTheme {
        LoginScreen(
            state = LoginUiState(
                email = "ada@example.com",
                password = "secret",
                error = LoginError.InvalidCredentials,
            ),
            onEmailChanged = {},
            onPasswordChanged = {},
            onSubmit = {},
            onForgotPassword = {},
        )
    }
}
