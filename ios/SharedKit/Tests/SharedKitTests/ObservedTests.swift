import SharedKit
import XCTest

/// `Observed` is tested against a real shared ViewModel: the bridge between Kotlin flows and
/// SwiftUI is the thing under test.
@MainActor
final class ObservedTests: XCTestCase {

    func testStateStartsWithTheCurrentValueOfTheViewModel() {
        let model = Observed(SharedGraph().loginViewModel(), state: \.state, as: LoginUiState.self)

        XCTAssertEqual(model.state.email, "")
        XCTAssertFalse(model.state.canSubmit)
    }

    func testSendRefreshesStateBeforeItReturns() {
        let model = Observed(SharedGraph().loginViewModel(), state: \.state, as: LoginUiState.self)

        model.send { $0.onEmailChanged(email: "ada@example.com") }

        XCTAssertEqual(model.state.email, "ada@example.com")
    }

    func testChangesMadeByTheViewModelReachTheState() async throws {
        let model = Observed(SharedGraph().loginViewModel(), state: \.state, as: LoginUiState.self)

        // Not through `send`: this change can only arrive through the flow.
        model.viewModel.onPasswordChanged(password: "kotlin")

        let deadline = ContinuousClock.now + .seconds(10)
        while model.state.password != "kotlin", ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.state.password, "kotlin")
    }
}
