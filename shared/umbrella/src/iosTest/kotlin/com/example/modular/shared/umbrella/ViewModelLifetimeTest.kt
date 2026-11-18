package com.example.modular.shared.umbrella

import androidx.lifecycle.ViewModel
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ViewModelLifetimeTest {

    private class RecordingViewModel : ViewModel() {
        var cleared = false
            private set

        override fun onCleared() {
            cleared = true
        }
    }

    @Test
    fun closeClearsTheViewModel() {
        val viewModel = RecordingViewModel()
        val lifetime = ViewModelLifetime(viewModel)
        assertFalse(viewModel.cleared)

        lifetime.close()

        assertTrue(viewModel.cleared)
    }
}
