package com.example.modular.shared.umbrella

import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain

@OptIn(ExperimentalCoroutinesApi::class)
class FlowSubscriptionTest {

    @BeforeTest
    fun setUp() {
        // The test runner blocks the main thread: values are delivered at once instead.
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun valuesArriveUntilTheSubscriptionIsCancelled() {
        val flow = MutableStateFlow(1)
        val values = mutableListOf<Any?>()
        var completions = 0
        val subscription = subscribe(flow, onValue = { values += it }, onCompletion = { completions++ })

        flow.value = 2
        subscription.cancel()
        flow.value = 3

        assertEquals(listOf<Any?>(1, 2), values)
        assertEquals(1, completions)
    }

    @Test
    fun completionIsReportedOnceWhenTheFlowEnds() {
        val values = mutableListOf<Any?>()
        var completions = 0

        val subscription = subscribe(flowOf("a", "b"), onValue = { values += it }, onCompletion = { completions++ })
        subscription.cancel()

        assertEquals(listOf<Any?>("a", "b"), values)
        assertEquals(1, completions)
    }
}
