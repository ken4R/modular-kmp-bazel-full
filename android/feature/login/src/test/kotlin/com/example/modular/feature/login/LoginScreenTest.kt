package com.example.modular.feature.login

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.modular.core.designsystem.ModularTheme
import com.example.modular.shared.feature.login.LoginError
import com.example.modular.shared.feature.login.LoginUiState
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Runs on the JVM with Robolectric: `./gradlew :android:feature:login:testDebugUnitTest`. */
@RunWith(AndroidJUnit4::class)
class LoginScreenTest {

    @get:Rule
    val composeRule = createComposeRule()

    private var typedEmail: String? = null
    private var submitCount = 0

    @Test
    fun submitIsDisabledWhileTheFormIsEmpty() {
        show(LoginUiState())

        composeRule.onNodeWithText("Se connecter").assertIsNotEnabled()
    }

    @Test
    fun submitIsForwardedWhenTheFormIsFilled() {
        show(LoginUiState(email = "ada@example.com", password = "kotlin"))

        composeRule.onNodeWithText("Se connecter").assertIsEnabled().performClick()

        assertEquals(1, submitCount)
    }

    @Test
    fun typingIsForwardedToTheSharedLogic() {
        show(LoginUiState())

        composeRule.onNodeWithText("E-mail").performTextInput("ada@example.com")

        assertEquals("ada@example.com", typedEmail)
    }

    @Test
    fun errorOfTheSharedStateIsDisplayed() {
        show(LoginUiState(email = "ada@example.com", password = "wrong", error = LoginError.InvalidCredentials))

        composeRule.onNodeWithText("E-mail ou mot de passe incorrect.").assertIsDisplayed()
    }

    private fun show(state: LoginUiState) {
        composeRule.setContent {
            ModularTheme {
                LoginScreen(
                    state = state,
                    onEmailChanged = { typedEmail = it },
                    onPasswordChanged = {},
                    onSubmit = { submitCount++ },
                    onForgotPassword = {},
                )
            }
        }
    }
}
