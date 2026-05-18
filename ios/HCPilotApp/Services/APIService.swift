import Foundation
import Alamofire

class APIService {
    static let shared = APIService()

    #if DEBUG
    private let baseURL = "http://localhost:8000"
    #else
    private let baseURL = "https://api.hcpilot.com"
    #endif

    private var authToken: String?

    private var headers: HTTPHeaders {
        var h = HTTPHeaders()
        h.add(.contentType("application/json"))
        if let token = authToken {
            h.add(.authorization(bearerToken: token))
        }
        return h
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Python's datetime.isoformat() can emit microseconds (6 digits).
            // DateFormatter only handles up to 3 reliably, so truncate.
            let normalized = dateString.replacingOccurrences(
                of: #"(\.\d{3})\d+"#,
                with: "$1",
                options: .regularExpression
            )
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd",
            ]
            for format in formats {
                let f = DateFormatter()
                f.dateFormat = format
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = f.date(from: normalized) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {}

    // MARK: - Auth Token Management

    func setToken(_ token: String) {
        authToken = token
    }

    func clearToken() {
        authToken = nil
    }

    // MARK: - Generic Requests

    private func get<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        let data = try await AF.request(url, headers: headers)
            .validate()
            .serializingData()
            .value
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ endpoint: String, body: Encodable) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        let jsonData = try encoder.encode(AnyEncodable(body))
        var request = URLRequest(url: url)
        request.method = .post
        request.headers = headers
        request.httpBody = jsonData

        let data = try await AF.request(request)
            .validate()
            .serializingData()
            .value
        return try decoder.decode(T.self, from: data)
    }

    private func postAction(_ endpoint: String) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        let data = try await AF.request(url, method: .post, headers: headers)
            .validate()
            .serializingData()
            .value
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        return json
    }

    private func put<T: Decodable>(_ endpoint: String, body: Encodable) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        let jsonData = try encoder.encode(AnyEncodable(body))
        var request = URLRequest(url: url)
        request.method = .put
        request.headers = headers
        request.httpBody = jsonData

        let data = try await AF.request(request)
            .validate()
            .serializingData()
            .value
        return try decoder.decode(T.self, from: data)
    }

    private func delete(_ endpoint: String) async throws {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        _ = try await AF.request(url, method: .delete, headers: headers)
            .validate()
            .serializingData()
            .value
    }

    // MARK: - Auth

    struct LoginResponse: Decodable {
        let access_token: String
        let token_type: String
        let user: UserProfile
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        let body = ["email": email, "password": password]
        let response: LoginResponse = try await post("/auth/login", body: body)
        setToken(response.access_token)
        return response
    }

    // MARK: - Visits

    func getVisits() async throws -> [Visit] {
        return try await get("/visits")
    }

    func createVisit(visit: Visit) async throws -> Visit {
        return try await post("/visits", body: visit)
    }

    func updateVisit(visit: Visit) async throws -> Visit {
        return try await put("/visits/\(visit.id)", body: visit)
    }

    func startVisit(visitId: String) async throws -> [String: Any] {
        return try await postAction("/visits/\(visitId)/start")
    }

    func completeVisit(visitId: String) async throws -> [String: Any] {
        return try await postAction("/visits/\(visitId)/complete")
    }

    // MARK: - Patients

    func getPatients() async throws -> [Patient] {
        return try await get("/patients")
    }

    func createPatient(patient: Patient) async throws -> Patient {
        return try await post("/patients", body: patient)
    }

    // MARK: - Stock

    func getStock() async throws -> [StockItem] {
        return try await get("/stock")
    }

    func addStockItem(item: StockItem) async throws -> StockItem {
        return try await post("/stock", body: item)
    }

    func updateStock(item: StockItem) async throws -> StockItem {
        return try await put("/stock/\(item.id)", body: item)
    }

    func deleteStock(itemId: String) async throws {
        try await delete("/stock/\(itemId)")
    }

    // MARK: - Invoices

    func getInvoices() async throws -> [Invoice] {
        return try await get("/invoices")
    }

    func createInvoice(invoice: Invoice) async throws -> Invoice {
        return try await post("/invoices", body: invoice)
    }

    // MARK: - Reports

    struct DashboardResponse: Decodable {
        let total_patients: Int
        let today_visits: Int
        let pending_invoices: Int
        let low_stock_alerts: Int
        let monthly_revenue: Double
        let visits_today: [Visit]
        let low_stock_items: [StockItem]
    }

    func getDashboard() async throws -> DashboardResponse {
        return try await get("/reports/dashboard")
    }

    struct RevenueResponse: Decodable {
        let total_revenue: Double
        let total_visits: Int
        let average_visit_value: Double
        let by_visit_type: [String: Double]
    }

    func getRevenueReport(startDate: String, endDate: String) async throws -> RevenueResponse {
        return try await get("/reports/revenue?start_date=\(startDate)&end_date=\(endDate)")
    }

    // MARK: - Route Optimization

    func optimizeRoute(visits: [Visit]) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + "/optimize/routes") else {
            throw APIError.invalidURL("/optimize/routes")
        }
        let jsonData = try encoder.encode(visits)
        var request = URLRequest(url: url)
        request.method = .post
        request.headers = headers
        request.httpBody = jsonData

        let data = try await AF.request(request)
            .validate()
            .serializingData()
            .value
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        return json
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL(let endpoint): return "URL invalide: \(endpoint)"
        case .invalidResponse: return "Réponse invalide du serveur"
        case .unauthorized: return "Session expirée, veuillez vous reconnecter"
        }
    }
}

// MARK: - AnyEncodable Wrapper

struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
