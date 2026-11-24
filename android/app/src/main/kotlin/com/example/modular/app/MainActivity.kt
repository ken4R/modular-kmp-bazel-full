package com.example.modular.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.example.modular.core.designsystem.ModularTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val graph = (application as ModularApplication).graph
        setContent {
            ModularTheme {
                AppRoot(graph)
            }
        }
    }
}
