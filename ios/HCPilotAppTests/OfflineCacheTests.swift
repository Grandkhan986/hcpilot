import XCTest
@testable import HCPilotApp

/// Brief §Gestion offline — cache disque des réponses lecture critiques.
final class OfflineCacheTests: XCTestCase {
    override func setUp() {
        super.setUp()
        OfflineCache.shared.clear()
    }

    override func tearDown() {
        OfflineCache.shared.clear()
        super.tearDown()
    }

    func test_loadReturnsNilWhenNoCache() {
        XCTAssertNil(OfflineCache.shared.load(for: "/clients"))
    }

    func test_saveThenLoadRoundtrips() {
        let payload = #"[{"id":"pat_001"}]"#.data(using: .utf8)!
        OfflineCache.shared.save(payload, for: "/clients")
        let cached = OfflineCache.shared.load(for: "/clients")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.data, payload)
        XCTAssertLessThan(Date().timeIntervalSince(cached?.savedAt ?? Date.distantPast), 5)
    }

    func test_differentEndpointsDoNotCollide() {
        let p1 = "client_a".data(using: .utf8)!
        let p2 = "client_b".data(using: .utf8)!
        OfflineCache.shared.save(p1, for: "/clients")
        OfflineCache.shared.save(p2, for: "/clients?archived=true")

        XCTAssertEqual(OfflineCache.shared.load(for: "/clients")?.data, p1)
        XCTAssertEqual(OfflineCache.shared.load(for: "/clients?archived=true")?.data, p2)
    }

    func test_sanitizeAcceptsQueryParams() {
        let p = "hello".data(using: .utf8)!
        OfflineCache.shared.save(p, for: "/reports/dashboard?start=2026-01-01&end=2026-12-31")
        XCTAssertEqual(
            OfflineCache.shared.load(for: "/reports/dashboard?start=2026-01-01&end=2026-12-31")?.data,
            p
        )
    }
}
