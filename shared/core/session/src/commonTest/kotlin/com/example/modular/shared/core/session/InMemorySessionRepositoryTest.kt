package com.example.modular.shared.core.session

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlinx.coroutines.test.runTest

class InMemorySessionRepositoryTest {

    private val repository = InMemorySessionRepository()

    @Test
    fun signInWithTheDemoPasswordOpensASession() = runTest {
        val result = repository.signIn("ada@example.com", InMemorySessionRepository.DEMO_PASSWORD)

        assertEquals(SignInResult.Success(Session(userName = "ada")), result)
        assertEquals(Session(userName = "ada"), repository.session.value)
    }

    @Test
    fun signInWithAnotherPasswordIsRejected() = runTest {
        val result = repository.signIn("ada@example.com", "wrong")

        assertEquals(SignInResult.InvalidCredentials, result)
        assertNull(repository.session.value)
    }

    @Test
    fun signOutClosesTheSession() = runTest {
        repository.signIn("ada@example.com", InMemorySessionRepository.DEMO_PASSWORD)

        repository.signOut()

        assertNull(repository.session.value)
    }
}
