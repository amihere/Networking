import XCTest
@testable import Networking

final class NetworkingTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        
        let networkable: Networkable = Networking.getDefault(tokenFinder: {""})
        XCTAssertEqual(networkable.tokenFinder!(), "")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
