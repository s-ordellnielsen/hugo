import XCTest

/// Keeps the UI test target buildable until the real tests exist. A test
/// bundle with no test file has no executable, and `xcodebuild test` fails to
/// load it. Delete this file when the first real UI test is added.
final class UITargetPlaceholderTests: XCTestCase {
    func testTargetLoads() {}
}
