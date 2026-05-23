import XCTest
@testable import HCPilotApp

/// Audit H-96 — vérifie le dédoublonnage dans MutationQueue.enqueue :
/// une mutation (endpoint, method) déjà queuée dans les 5 dernières secondes
/// n'est pas re-enqueuée.
@MainActor
final class MutationQueueDedupeTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Repartir d'une queue vide pour isoler le test.
        MutationQueue.shared.clear()
    }

    override func tearDown() async throws {
        MutationQueue.shared.clear()
        try await super.tearDown()
    }

    func test_recent_duplicate_is_not_enqueued() {
        let endpoint = "/sessions/vis_test/start"
        MutationQueue.shared.enqueue(endpoint: endpoint, method: "POST", body: nil)
        MutationQueue.shared.enqueue(endpoint: endpoint, method: "POST", body: nil)

        XCTAssertEqual(MutationQueue.shared.count, 1, "Le second enqueue identique doit être ignoré (<5s)")
    }

    func test_different_endpoint_is_enqueued_independently() {
        MutationQueue.shared.enqueue(endpoint: "/a", method: "POST", body: nil)
        MutationQueue.shared.enqueue(endpoint: "/b", method: "POST", body: nil)

        XCTAssertEqual(MutationQueue.shared.count, 2, "Endpoints différents doivent coexister")
    }

    func test_same_endpoint_different_method_is_enqueued() {
        MutationQueue.shared.enqueue(endpoint: "/x", method: "POST", body: nil)
        MutationQueue.shared.enqueue(endpoint: "/x", method: "DELETE", body: nil)

        XCTAssertEqual(MutationQueue.shared.count, 2, "Même endpoint mais method ≠ doivent coexister")
    }

    func test_clear_resets_queue() {
        MutationQueue.shared.enqueue(endpoint: "/x", method: "POST", body: nil)
        MutationQueue.shared.enqueue(endpoint: "/y", method: "DELETE", body: nil)
        XCTAssertEqual(MutationQueue.shared.count, 2)

        MutationQueue.shared.clear()
        XCTAssertEqual(MutationQueue.shared.count, 0)
    }
}
