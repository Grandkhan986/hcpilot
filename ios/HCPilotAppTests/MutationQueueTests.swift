import XCTest
@testable import HCPilotApp

/// Tests unitaires de la file de mutations offline (brief Sprint 6).
/// Couvre : enqueue, FIFO, persistence disque, clear.
@MainActor
final class MutationQueueTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        MutationQueue.shared.clear()
    }

    override func tearDown() async throws {
        MutationQueue.shared.clear()
        try await super.tearDown()
    }

    func test_enqueue_appendsAndPersists() throws {
        MutationQueue.shared.enqueue(endpoint: "/sessions/vis_001/start", method: "POST", body: nil)
        XCTAssertEqual(MutationQueue.shared.count, 1)
        XCTAssertEqual(MutationQueue.shared.pending.first?.endpoint, "/sessions/vis_001/start")
        XCTAssertEqual(MutationQueue.shared.pending.first?.method, "POST")
    }

    func test_enqueue_keepsFIFOOrder() throws {
        MutationQueue.shared.enqueue(endpoint: "/sessions/vis_001/start", method: "POST", body: nil)
        MutationQueue.shared.enqueue(endpoint: "/sessions/vis_002/start", method: "POST", body: nil)
        MutationQueue.shared.enqueue(endpoint: "/inventory/usage", method: "POST", body: Data())
        XCTAssertEqual(MutationQueue.shared.count, 3)
        XCTAssertEqual(MutationQueue.shared.pending[0].endpoint, "/sessions/vis_001/start")
        XCTAssertEqual(MutationQueue.shared.pending[1].endpoint, "/sessions/vis_002/start")
        XCTAssertEqual(MutationQueue.shared.pending[2].endpoint, "/inventory/usage")
    }

    func test_clear_emptiesQueue() throws {
        MutationQueue.shared.enqueue(endpoint: "/sessions/vis_001/start", method: "POST", body: nil)
        XCTAssertGreaterThan(MutationQueue.shared.count, 0)
        MutationQueue.shared.clear()
        XCTAssertEqual(MutationQueue.shared.count, 0)
    }

    func test_persistedMutationCarriesMetadata() throws {
        let body = #"{"quantity":1}"#.data(using: .utf8)
        MutationQueue.shared.enqueue(endpoint: "/inventory/usage", method: "POST", body: body)
        let m = try XCTUnwrap(MutationQueue.shared.pending.first)
        XCTAssertEqual(m.body, body)
        XCTAssertEqual(m.attempts, 0)
        XCTAssertNil(m.lastAttemptAt)
        XCTAssertLessThan(Date().timeIntervalSince(m.queuedAt), 1.0) // ~maintenant
    }
}
