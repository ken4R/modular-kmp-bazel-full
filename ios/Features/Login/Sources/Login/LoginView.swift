import SharedKit
import SwiftUI

/// The login screen, bound to the shared `LoginViewModel`.
///
/// The view owns its ViewModel for as long as it is on screen. Navigation stays outside:
/// the application says what happens when the user is signed in or asks for a new password.
public struct LoginView: View {

    private let makeViewModel: () -> LoginViewModel
    private let onSignedIn: (String) -> Void
    private let onPasswordResetRequested: (String) -> Void

    @State private var model: Observed<LoginViewModel, LoginUiState>?

    /// - Parameters:
    ///   - viewModel: evaluated once, when the screen appears: pass `graph.loginViewModel()`.
    ///   - onSignedIn: called with the name of the user.
    ///   - onPasswordResetRequested: called with the e-mail address typed so far, which may be blank.
    public init(
        viewModel: @autoclosure @escaping () -> LoginViewModel,
        onSignedIn: @escaping (String) -> Void,
        onPasswordResetRequested: @escaping (String) -> Void
    ) {
        self.makeViewModel = viewModel
        self.onSignedIn = onSignedIn
        self.onPasswordResetRequested = onPasswordResetRequested
    }

    public var body: some View {
        ZStack {
            // Always there, so the task below starts even before the form exists.
            Color.clear
            if let model {
                LoginForm(
                    state: model.state,
                    onEmailChanged: { email in model.send { $0.onEmailChanged(email: email) } },
                    onPasswordChanged: { password in model.send { $0.onPasswordChanged(password: password) } },
                    onSubmit: { model.send { $0.submit() } },
                    onForgotPassword: { model.send { $0.requestPasswordReset() } }
                )
            }
        }
        .task {
            // Created here and not in `init`: SwiftUI builds this struct many times, but the
            // screen needs one ViewModel.
            let model = self.model ?? Observed(makeViewModel(), state: \.state, as: LoginUiState.self)
            self.model = model
            await forwardEvents(of: model.viewModel)
        }
    }

    /// Hands the events of the ViewModel to the application, until the surrounding task is cancelled.
    func forwardEvents(of viewModel: LoginViewModel) async {
        for await event in viewModel.events.values(of: LoginEvent.self) {
            // Swift sees the Kotlin sealed interface as a protocol: the compiler cannot check that
            // every event is handled.
            switch event {
            case let event as LoginEventSignedIn:
                onSignedIn(event.userName)
            case let event as LoginEventPasswordResetRequested:
                onPasswordResetRequested(event.email)
            default:
                assertionFailure("LoginView does not handle \(event).")
            }
        }
    }
}
