import Observation
import Shared

/// Makes a shared ViewModel observable by SwiftUI and gives it an owner.
///
///     let model = Observed(graph.loginViewModel(), state: \.state, as: LoginUiState.self)
///
/// - `state` is the latest value published by the ViewModel. SwiftUI redraws when it changes.
///   Swift sees a Kotlin `StateFlow` without its type parameter: `as` gives the type back.
/// - `send` calls the ViewModel and refreshes `state` before it returns, so a text field
///   never shows a value older than what the user just typed.
/// - When the last reference goes away, the ViewModel is cleared and its coroutines are
///   cancelled. On Android an activity or a navigation entry plays this role.
///
/// The state flow must hold a non-optional value: a screen always has a state.
@MainActor
@Observable
public final class Observed<VM: ViewModel, UiState> {

    public let viewModel: VM
    public private(set) var state: UiState

    @ObservationIgnored private let flow: any Kotlinx_coroutines_coreStateFlow
    @ObservationIgnored private let lifetime: ViewModelLifetime
    @ObservationIgnored private var subscription: FlowSubscription?

    public init(
        _ viewModel: VM,
        state: KeyPath<VM, any Kotlinx_coroutines_coreStateFlow>,
        as type: UiState.Type
    ) {
        let flow = viewModel[keyPath: state]
        self.viewModel = viewModel
        self.flow = flow
        self.state = flow.value as! UiState
        self.lifetime = ViewModelLifetime(viewModel: viewModel)
        // Changes the ViewModel makes on its own, for example when a request ends. Kotlin calls
        // back on the main thread. A Kotlin lambda that returns Unit returns KotlinUnit in Swift.
        self.subscription = FlowSubscriptionKt.subscribe(
            flow: flow,
            onValue: { [weak self] value in
                MainActor.assumeIsolated {
                    self?.state = value as! UiState
                }
                return KotlinUnit()
            },
            onCompletion: { KotlinUnit() }
        )
    }

    /// Calls the ViewModel, then reads its new state at once.
    public func send(_ action: (VM) -> Void) {
        action(viewModel)
        state = flow.value as! UiState
    }

    deinit {
        subscription?.cancel()
        lifetime.close()
    }
}
