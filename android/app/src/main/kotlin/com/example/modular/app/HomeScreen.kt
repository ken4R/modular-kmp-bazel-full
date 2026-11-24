package com.example.modular.app

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.modular.core.designsystem.PrimaryButton

/** Placeholder for what comes after login. It stays in the app module until a real feature replaces it. */
@Composable
fun HomeScreen(
    userName: String,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var signingOut by remember { mutableStateOf(false) }

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
                text = stringResource(R.string.home_greeting, userName),
                style = MaterialTheme.typography.headlineMedium,
            )
            PrimaryButton(
                text = stringResource(R.string.home_sign_out),
                onClick = {
                    signingOut = true
                    onSignOut()
                },
                loading = signingOut,
            )
        }
    }
}
