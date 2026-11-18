package com.example.modular.app

import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.modular.feature.login.LoginRoute
import com.example.modular.shared.umbrella.SharedGraph
import kotlinx.coroutines.launch

/**
 * Root navigation of the prototype: two destinations and no navigation library yet.
 * Features emit navigation intents, this is the only place that decides where they lead.
 */
@Composable
fun AppRoot(graph: SharedGraph) {
    var signedInUser by rememberSaveable { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val userName = signedInUser
    if (userName == null) {
        LoginRoute(
            // The activity owns the ViewModel, so it survives rotation.
            viewModel = viewModel { graph.loginViewModel() },
            onSignedIn = { signedInUser = it },
            onPasswordResetRequested = {
                Toast.makeText(context, R.string.password_reset_placeholder, Toast.LENGTH_SHORT).show()
            },
        )
    } else {
        HomeScreen(
            userName = userName,
            onSignOut = {
                scope.launch {
                    graph.signOut()
                    signedInUser = null
                }
            },
        )
    }
}
