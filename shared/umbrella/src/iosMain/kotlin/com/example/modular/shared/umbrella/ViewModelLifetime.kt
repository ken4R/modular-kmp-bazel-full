package com.example.modular.shared.umbrella

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.viewmodel.CreationExtras
import kotlin.reflect.KClass

/**
 * Ends the life of a ViewModel from Swift.
 *
 * On Android an activity or a navigation entry owns each ViewModel and clears it. SwiftUI has no
 * such owner, so SharedKit creates one [ViewModelLifetime] per screen and calls [close] when the
 * screen goes away: the ViewModel's coroutines are cancelled and `onCleared` runs.
 */
public class ViewModelLifetime(viewModel: ViewModel) {

    private val store = ViewModelStore()

    init {
        // Registers the existing instance in the store through the public API.
        val factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: KClass<T>, extras: CreationExtras): T = viewModel as T
        }
        @Suppress("UNCHECKED_CAST")
        val modelClass = viewModel::class as KClass<ViewModel>
        ViewModelProvider.create(store, factory)[modelClass]
    }

    public fun close() {
        store.clear()
    }
}
