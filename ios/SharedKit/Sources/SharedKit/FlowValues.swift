import Shared

extension Kotlinx_coroutines_coreFlow {

    /// The values of a Kotlin flow, as an `AsyncStream` that yields on the main thread.
    ///
    ///     for await event in viewModel.events.values(of: LoginEvent.self) { ... }
    ///
    /// Swift sees a Kotlin `Flow` without its type parameter: `type` gives it back, and a value of
    /// another type stops the application. The flow is collected while the loop runs: leaving the
    /// loop or cancelling its task cancels the collection. The loop ends when the flow ends.
    public func values<Value>(of type: Value.Type) -> AsyncStream<Value> {
        AsyncStream { continuation in
            let subscription = FlowSubscriptionKt.subscribe(
                flow: self,
                onValue: { value in
                    continuation.yield(value as! Value)
                    return KotlinUnit()
                },
                onCompletion: {
                    continuation.finish()
                    return KotlinUnit()
                }
            )
            continuation.onTermination = { _ in
                subscription.cancel()
            }
        }
    }
}
