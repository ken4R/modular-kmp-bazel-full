import SharedKit
import XCTest

@testable import Login

/// The view has one job besides drawing: handing the events of the shared ViewModel to the
/// application. These tests drive the real ViewModel, so they also cover the Kotlin-to-Swift bridge.
@MainActor
final class LoginViewTests: XCTestCase {

    func testSigningInTellsTheApplicationWhoSignedIn() async {
        let viewModel = SharedGraph().loginViewModel()
        let signedIn = expectation(description: "The application learns who signed in")
        let view = LoginView(
            viewModel: viewModel,
            onSignedIn: { userName in
                XCTAssertEqual(userName, "ada")
                signedIn.fulfill()
            },
            onPasswordResetRequested: { _ in XCTFail("Nobody asked for a new password.") }
        )
        let forwarding = Task { await view.forwardEvents(of: viewModel) }

        viewModel.onEmailChanged(email: "ada@example.com")
        viewModel.onPasswordChanged(password: "kotlin")
        viewModel.submit()

        await fulfillment(of: [signedIn], timeout: 10)
        forwarding.cancel()
    }

    func testAskingForANewPasswordTellsTheApplicationWhichAddress() async {
        let viewModel = SharedGraph().loginViewModel()
        let requested = expectation(description: "The application learns which address to reset")
        let view = LoginView(
            viewModel: viewModel,
            onSignedIn: { _ in XCTFail("Nobody signed in.") },
            onPasswordResetRequested: { email in
                XCTAssertEqual(email, "ada@example.com")
                requested.fulfill()
            }
        )
        let forwarding = Task { await view.forwardEvents(of: viewModel) }

        viewModel.onEmailChanged(email: "ada@example.com")
        viewModel.requestPasswordReset()

        await fulfillment(of: [requested], timeout: 10)
        forwarding.cancel()
    }
}
