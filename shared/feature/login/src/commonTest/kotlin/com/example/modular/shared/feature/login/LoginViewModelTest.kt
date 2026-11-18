package com.example.modular.shared.feature.login

import com.example.modular.shared.core.session.InMemorySessionRepository
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain

@OptIn(ExperimentalCoroutinesApi::class)
class LoginViewModelTest {

    private val sessions = InMemorySessionRepository()

    @BeforeTest
    fun setUp() {
        // viewModelScope runs on Dispatchers.Main: tests replace it with a dispatcher they control.
        Dispatchers.setMain(StandardTestDispatcher())
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun formCannotBeSentUntilItIsFilled() {
        val viewModel = LoginViewModel(sessions)
        assertFalse(viewModel.state.value.canSubmit)

        viewModel.onEmailChanged("ada@example.com")
        assertFalse(viewModel.state.value.canSubmit)

        viewModel.onPasswordChanged("kotlin")
        assertTrue(viewModel.state.value.canSubmit)
    }

    @Test
    fun submitWithTheRightPasswordSignsIn() = runTest {
        val viewModel = LoginViewModel(sessions)
        viewModel.onEmailChanged("ada@example.com")
        viewModel.onPasswordChanged(InMemorySessionRepository.DEMO_PASSWORD)

        viewModel.submit()
        assertTrue(viewModel.state.value.isSubmitting)

        advanceUntilIdle()
        assertEquals(LoginEvent.SignedIn(userName = "ada"), viewModel.events.first())
        assertEquals(
            LoginUiState(email = "ada@example.com", password = "", isSubmitting = false, error = null),
            viewModel.state.value,
        )
        assertEquals("ada", sessions.session.value?.userName)
    }

    @Test
    fun submitWithAWrongPasswordReportsInvalidCredentials() = runTest {
        val viewModel = LoginViewModel(sessions)
        viewModel.onEmailChanged("ada@example.com")
        viewModel.onPasswordChanged("wrong")

        viewModel.submit()
        advanceUntilIdle()

        assertEquals(LoginError.InvalidCredentials, viewModel.state.value.error)
        assertFalse(viewModel.state.value.isSubmitting)
        assertNull(sessions.session.value)
    }

    @Test
    fun submitWithAMalformedEmailNeverCallsTheRepository() = runTest {
        val viewModel = LoginViewModel(sessions)
        viewModel.onEmailChanged("not an email")
        viewModel.onPasswordChanged(InMemorySessionRepository.DEMO_PASSWORD)

        viewModel.submit()
        advanceUntilIdle()

        assertEquals(LoginError.InvalidEmail, viewModel.state.value.error)
        assertFalse(viewModel.state.value.isSubmitting)
        assertNull(sessions.session.value)
    }

    @Test
    fun editingTheFormClearsTheError() = runTest {
        val viewModel = LoginViewModel(sessions)
        viewModel.onEmailChanged("ada@example.com")
        viewModel.onPasswordChanged("wrong")
        viewModel.submit()
        advanceUntilIdle()

        viewModel.onPasswordChanged("kotlin")

        assertNull(viewModel.state.value.error)
    }

    @Test
    fun passwordResetIsANavigationIntent() = runTest {
        val viewModel = LoginViewModel(sessions)
        viewModel.onEmailChanged(" ada@example.com ")

        viewModel.requestPasswordReset()

        assertEquals(LoginEvent.PasswordResetRequested(email = "ada@example.com"), viewModel.events.first())
    }

    @Test
    fun emailValidationIsLoose() {
        assertTrue(isValidEmail("ada@example.com"))
        assertFalse(isValidEmail("ada"))
        assertFalse(isValidEmail("@example.com"))
        assertFalse(isValidEmail("ada@"))
        assertFalse(isValidEmail("ada@exa mple.com"))
        assertFalse(isValidEmail("ada@@example.com"))
    }
}
