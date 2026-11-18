package com.example.modular.shared.umbrella

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

/**
 * Collects a flow for Swift.
 *
 * The framework is linked without SKIE: Swift sees a `Flow` as a bare Objective-C protocol, without
 * its type parameter and without `AsyncSequence`. SharedKit builds its Swift adapters on [subscribe]
 * instead, so that SwiftUI code never handles coroutines.
 */
public class FlowSubscription internal constructor(private val job: Job) {

    /** Stops the collection. [subscribe] then reports the completion, and no value arrives after it. */
    public fun cancel() {
        job.cancel()
    }
}

/**
 * Collects [flow] on the main thread: [onValue] receives each value, then [onCompletion] runs once,
 * when the flow ends or when the subscription is cancelled. The caller keeps the subscription and
 * cancels it when it no longer needs the values.
 */
public fun subscribe(flow: Flow<*>, onValue: (Any?) -> Unit, onCompletion: () -> Unit): FlowSubscription {
    val job = CoroutineScope(Dispatchers.Main).launch {
        try {
            flow.collect { onValue(it) }
        } finally {
            onCompletion()
        }
    }
    return FlowSubscription(job)
}
