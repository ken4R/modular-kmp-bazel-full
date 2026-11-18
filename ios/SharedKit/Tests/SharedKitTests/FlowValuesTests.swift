import SharedKit
import XCTest

/// `values(of:)` is tested against the events of a real shared ViewModel.
@MainActor
final class FlowValuesTests: XCTestCase {

    func testEventsArriveAsTypedValues() async {
        let viewModel = SharedGraph().loginViewModel()
        viewModel.onEmailChanged(email: "ada@example.com")
        viewModel.requestPasswordReset()

        for await event in viewModel.events.values(of: LoginEvent.self) {
            XCTAssertEqual((event as? LoginEventPasswordResetRequested)?.email, "ada@example.com")
            return
        }
        XCTFail("The events ended before the first one arrived.")
    }
}
