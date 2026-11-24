package com.example.modular.app

import android.app.Application
import com.example.modular.shared.umbrella.SharedGraph

class ModularApplication : Application() {

    /** One graph for the whole process: it owns what the shared code keeps in memory. */
    val graph: SharedGraph by lazy { SharedGraph() }
}
