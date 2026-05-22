import Foundation
import Alamofire

class APIService {
    static let shared = APIService()

    // Audit H14 : versionning d'API. Préfixe `/v1` côté client pour permettre
    // d'évoluer l'API serveur sans casser les builds App Store antérieurs.
    // Le backend FastAPI accepte aussi les routes nues (middleware de réécriture).
    #if DEBUG
    private let baseURL = "http://localhost:8000/v1"
    #else
    private let baseURL = "https://api.hcpilot.com/v1"
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
        // Audit H2 : conversion automatique snake_case JSON → camelCase Swift.
        // Évite d'écrire des CodingKeys explicites dans chaque Model.
        d.keyDecodingStrategy = .convertFromSnakeCase
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
        // Audit H2 : symétrique du décodeur — Swift camelCase → JSON snake_case.
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// Audit M8 — timeouts par catégorie d'appel.
    /// - `default` : 30 s pour les GET/POST courts (CRUD, dashboard, login).
    /// - `upload`  : 60 s pour POST avec body lourd (PDF de consentement b64).
    /// - `download`: 120 s pour les GET volumineux (PDF, audit logs paginés).
    enum RequestTimeout {
        static let `default`: TimeInterval = 30
        static let upload: TimeInterval = 60
        static let download: TimeInterval = 120
    }

    /// Audit M8 — `Alamofire.Session` dédiée avec timeouts par défaut.
    /// Pas d'utilisation de `AF.default` afin d'avoir un point unique pour
    /// configurer pinning / interceptors lorsque le backend prod sera prêt.
    /// Le nom `afSession` évite la collision avec notre model `Session` (IV).
    private let afSession: Alamofire.Session = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = RequestTimeout.default
        config.timeoutIntervalForResource = RequestTimeout.download
        return Alamofire.Session(configuration: config)
    }()

    private init() {
        // Restaure le token depuis le Keychain au boot (session persistante
        // sauf si expirée par inactivité — l'AuthViewModel s'en charge).
        self.authToken = SecureStorage.shared.getString(forKey: .authToken)
    }

    // MARK: - Auth Token Management

    func setToken(_ token: String) {
        authToken = token
        SecureStorage.shared.setString(token, forKey: .authToken)
        SecureStorage.shared.setDate(Date(), forKey: .lastActivity)
    }

    func clearToken() {
        authToken = nil
        SecureStorage.shared.clearSession()
    }

    /// Met à jour le timestamp d'activité — appelé à chaque requête HTTP.
    /// Permet à l'AuthViewModel de juger si la session doit être verrouillée.
    private func touchActivity() {
        SecureStorage.shared.setDate(Date(), forKey: .lastActivity)
    }

    // MARK: - Generic Requests

    private func get<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        if authToken != nil { touchActivity() }
        do {
            let data = try await afSession.request(url, headers: headers)
                .validate()
                .serializingData()
                .value
            return try decoder.decode(T.self, from: data)
        } catch {
            throw intercept(error)
        }
    }

    /// GET avec cache de secours offline (brief §Gestion offline).
    /// Comportement :
    ///   1. Tente l'appel réseau ; sur succès, persiste la réponse + marque online.
    ///   2. Sur échec réseau, retombe sur la dernière réponse cachée et marque
    ///      l'app comme étant en mode offline avec un horodatage de fraîcheur.
    ///   3. Si pas de cache, propage l'erreur.
    private func cachedGet<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        if authToken != nil { touchActivity() }
        do {
            let data = try await afSession.request(url, headers: headers)
                .validate()
                .serializingData()
                .value
            OfflineCache.shared.save(data, for: endpoint)
            let wasOffline = await MainActor.run { () -> Bool in
                let prev = ConnectivityState.shared.isOffline
                ConnectivityState.shared.markOnline()
                return prev
            }
            // Connexion qui vient de revenir → drainer les mutations en attente
            if wasOffline {
                Task { await MutationQueue.shared.drain(via: self) }
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            // 401 = session invalide. On NE retombe PAS sur le cache offline
            // (servirait des données stale d'une session qui n'est plus la
            // bonne) ; on déclenche l'auto-logout.
            if statusCode(from: error) == 401 {
                throw intercept(error)
            }
            if let cached = OfflineCache.shared.load(for: endpoint) {
                await MainActor.run {
                    ConnectivityState.shared.markOffline(cachedAt: cached.savedAt)
                }
                return try decoder.decode(T.self, from: cached.data)
            }
            throw error
        }
    }

    private func post<T: Decodable>(_ endpoint: String, body: Encodable) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        if authToken != nil { touchActivity() }
        let jsonData = try encoder.encode(AnyEncodable(body))
        var request = URLRequest(url: url)
        request.method = .post
        request.headers = headers
        request.httpBody = jsonData

        do {
            let data = try await afSession.request(request)
                .validate()
                .serializingData()
                .value
            return try decoder.decode(T.self, from: data)
        } catch {
            throw intercept(error)
        }
    }

    private func postAction(_ endpoint: String) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        if authToken != nil { touchActivity() }
        do {
            let data = try await afSession.request(url, method: .post, headers: headers)
                .validate()
                .serializingData()
                .value
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw APIError.invalidResponse
            }
            return json
        } catch {
            throw intercept(error)
        }
    }

    // MARK: - Offline mutations (brief §Gestion offline)

    enum MutationReplayError: Error {
        case networkUnavailable
        case permanentFailure
    }

    /// Erreur lancée quand une mutation est mise en queue offline. Le call site
    /// peut traiter ça comme un quasi-succès (l'action sera rejouée plus tard).
    enum QueuedError: Error {
        case enqueued
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let afError = error as? AFError {
            switch afError {
            case .sessionTaskFailed: return true
            case .invalidURL, .createUploadableFailed, .createURLRequestFailed: return false
            default: return false
            }
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    /// Audit H15 — détection du 401 + broadcast unique pour auto-logout.
    /// Toute requête qui prend un 401 purge la session locale et notifie
    /// `AuthViewModel` via `Notification.Name.hcpilotSessionUnauthorized` ;
    /// l'UI repasse alors sur l'écran de login plutôt que de remonter une
    /// erreur cryptique à l'utilisateur.
    private func statusCode(from error: Error) -> Int? {
        if let afError = error.asAFError,
           case .responseValidationFailed(let reason) = afError,
           case .unacceptableStatusCode(let code) = reason {
            return code
        }
        return nil
    }

    @discardableResult
    private func intercept(_ error: Error) -> Error {
        guard statusCode(from: error) == 401 else { return error }
        // Token rejeté serveur → purge locale immédiate et notification.
        // Sync clearToken (touche le Keychain) puis broadcast.
        clearToken()
        NotificationCenter.default.post(name: .hcpilotSessionUnauthorized, object: nil)
        return APIError.unauthorized
    }

    /// POST sans body (action) avec mise en queue offline. Renvoie le JSON
    /// sur succès, ou lance `QueuedError.enqueued` si la mutation a été
    /// mise en file (offline).
    func queuedPostAction(_ endpoint: String) async throws -> [String: Any] {
        do {
            let result = try await postAction(endpoint)
            // Tente de drainer d'éventuelles mutations en attente (la connectivité
            // vient peut-être de revenir).
            Task { await MutationQueue.shared.drain(via: self) }
            return result
        } catch {
            if isNetworkError(error) {
                await MainActor.run {
                    MutationQueue.shared.enqueue(endpoint: endpoint, method: "POST", body: nil)
                    ConnectivityState.shared.markOffline(cachedAt: Date())
                }
                throw QueuedError.enqueued
            }
            throw error
        }
    }

    /// DELETE avec mise en queue offline.
    func queuedDelete(_ endpoint: String) async throws {
        do {
            try await delete(endpoint)
            Task { await MutationQueue.shared.drain(via: self) }
        } catch {
            if isNetworkError(error) {
                await MainActor.run {
                    MutationQueue.shared.enqueue(endpoint: endpoint, method: "DELETE", body: nil)
                    ConnectivityState.shared.markOffline(cachedAt: Date())
                }
                throw QueuedError.enqueued
            }
            throw error
        }
    }

    /// POST avec body (typé) + mise en queue offline. Renvoie le résultat typé
    /// sur succès, ou lance `QueuedError.enqueued` si offline.
    func queuedPost<T: Decodable>(_ endpoint: String, body: Encodable) async throws -> T {
        do {
            let result: T = try await post(endpoint, body: body)
            Task { await MutationQueue.shared.drain(via: self) }
            return result
        } catch {
            if isNetworkError(error) {
                let jsonData = (try? encoder.encode(AnyEncodable(body))) ?? Data()
                await MainActor.run {
                    MutationQueue.shared.enqueue(endpoint: endpoint, method: "POST", body: jsonData)
                    ConnectivityState.shared.markOffline(cachedAt: Date())
                }
                throw QueuedError.enqueued
            }
            throw error
        }
    }

    /// Rejoue une mutation depuis la file. Distingue les erreurs réseau
    /// (toujours offline, garder en file) des erreurs serveur (drop).
    func replay(mutation: PendingMutation) async throws {
        guard let url = URL(string: baseURL + mutation.endpoint) else {
            throw MutationReplayError.permanentFailure
        }
        var request = URLRequest(url: url)
        request.httpMethod = mutation.method
        request.allHTTPHeaderFields = headers.dictionary
        if let body = mutation.body, !body.isEmpty {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            _ = try await afSession.request(request)
                .validate()
                .serializingData()
                .value
            // Succès → mark online (la connectivité est revenue)
            await MainActor.run { ConnectivityState.shared.markOnline() }
        } catch {
            if isNetworkError(error) {
                throw MutationReplayError.networkUnavailable
            }
            // 4xx/5xx → mutation périmée, on drop (last-write-wins per brief)
            throw MutationReplayError.permanentFailure
        }
    }

    private func put<T: Decodable>(_ endpoint: String, body: Encodable) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        if authToken != nil { touchActivity() }
        let jsonData = try encoder.encode(AnyEncodable(body))
        var request = URLRequest(url: url)
        request.method = .put
        request.headers = headers
        request.httpBody = jsonData

        do {
            let data = try await afSession.request(request)
                .validate()
                .serializingData()
                .value
            return try decoder.decode(T.self, from: data)
        } catch {
            throw intercept(error)
        }
    }

    private func delete(_ endpoint: String) async throws {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        if authToken != nil { touchActivity() }
        do {
            _ = try await afSession.request(url, method: .delete, headers: headers)
                .validate()
                .serializingData()
                .value
        } catch {
            throw intercept(error)
        }
    }

    private func deleteReturning<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        if authToken != nil { touchActivity() }
        do {
            let data = try await afSession.request(url, method: .delete, headers: headers)
                .validate()
                .serializingData()
                .value
            return try decoder.decode(T.self, from: data)
        } catch {
            throw intercept(error)
        }
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        let body = ["email": email, "password": password]
        let response: LoginResponse = try await post("/auth/login", body: body)
        setToken(response.accessToken)
        return response
    }

    // MARK: - Sessions

    func getSessions() async throws -> [Session] {
        return try await cachedGet("/sessions")
    }

    func createSession(session: Session) async throws -> Session {
        return try await post("/sessions", body: session)
    }

    func updateSession(session: Session) async throws -> Session {
        return try await put("/sessions/\(session.id)", body: session)
    }

    func updateSession(id: String, patch: SessionPatch) async throws -> Session {
        return try await put("/sessions/\(id)", body: patch)
    }

    /// Soft-delete: marque la session comme annulée (status=cancelled).
    /// Offline-safe : mise en queue si le réseau tombe.
    func deleteSession(id: String) async throws {
        try await queuedDelete("/sessions/\(id)")
    }

    /// Clock-in. Offline-safe : si le réseau tombe, la mutation est mise en queue
    /// et rejouée au retour de connectivité.
    func startSession(sessionId: String) async throws -> [String: Any] {
        return try await queuedPostAction("/sessions/\(sessionId)/start")
    }

    /// Clock-out. Offline-safe (idem startSession).
    func completeSession(sessionId: String) async throws -> [String: Any] {
        return try await queuedPostAction("/sessions/\(sessionId)/complete")
    }

    // MARK: - Clients

    func getClients(archived: Bool = false) async throws -> [Client] {
        return try await cachedGet("/clients?archived=\(archived)")
    }

    func createClient(client: Client) async throws -> Client {
        return try await post("/clients", body: client)
    }

    func updateClient(id: String, patch: ClientPatch) async throws -> UpdatedClientResponse {
        return try await put("/clients/\(id)", body: patch)
    }

    func archiveClient(id: String) async throws -> ArchiveClientResponse {
        return try await deleteReturning("/clients/\(id)")
    }

    func restoreClient(id: String) async throws {
        _ = try await postAction("/clients/\(id)/restore")
    }

    // MARK: - Inventory (lots-tracked)

    func getInventoryLots(includeDepleted: Bool = false) async throws -> [InventoryLot] {
        return try await cachedGet("/inventory/lots?include_depleted=\(includeDepleted)")
    }

    func getInventoryProducts() async throws -> [InventoryProduct] {
        return try await cachedGet("/inventory/products")
    }

    func getInventoryLot(id: String) async throws -> InventoryLot {
        return try await get("/inventory/lots/\(id)")
    }

    func createInventoryLot(_ payload: CreateLotRequest) async throws -> InventoryLot {
        return try await post("/inventory/lots", body: payload)
    }

    func findLotsByBarcode(_ barcode: String) async throws -> [InventoryLot] {
        return try await get("/inventory/by_barcode/\(barcode)")
    }

    /// Décrément de stock. Offline-safe : mise en queue si réseau indispo
    /// (la nurse peut consommer un lot en mode hors-ligne, sync au retour).
    func recordUsage(_ payload: RecordUsageRequest) async throws -> RecordUsageResponse {
        return try await queuedPost("/inventory/usage", body: payload)
    }

    func getLotTransactions(lotId: String) async throws -> [InventoryTransaction] {
        return try await get("/inventory/lots/\(lotId)/transactions")
    }

    // MARK: - Invoices

    func getInvoices() async throws -> [Invoice] {
        return try await get("/invoices")
    }

    func createInvoice(invoice: Invoice) async throws -> Invoice {
        return try await post("/invoices", body: invoice)
    }

    // MARK: - Reports

    func getDashboard() async throws -> DashboardResponse {
        return try await cachedGet("/reports/dashboard")
    }

    func getRevenueReport(startDate: String, endDate: String) async throws -> RevenueResponse {
        return try await get("/reports/revenue?start_date=\(startDate)&end_date=\(endDate)")
    }

    // MARK: - Compliance

    func getComplianceDashboard() async throws -> ComplianceDashboard {
        return try await cachedGet("/compliance/dashboard")
    }

    func getStandingOrders() async throws -> [StandingOrderInfo] {
        return try await cachedGet("/compliance/standingOrders")
    }

    func acknowledgeAlert(id: String) async throws {
        _ = try await postAction("/compliance/alerts/\(id)/acknowledge")
    }

    // MARK: - Onboarding (wizard Sprint 1)

    func updatePractice(_ payload: UpdatePracticeRequest) async throws -> PracticeResponse {
        return try await put("/users/me/practice", body: payload)
    }

    func createMedicalDirector(_ payload: CreateMedicalDirectorRequest) async throws -> MedicalDirectorInfo {
        return try await post("/compliance/medical_directors", body: payload)
    }

    func createStandingOrder(_ payload: CreateStandingOrderRequest) async throws -> StandingOrderInfo {
        return try await post("/compliance/standingOrders", body: payload)
    }

    // MARK: - Audit Logs

    func getAuditLogs(entityType: String? = nil, limit: Int = 100) async throws -> [AuditLogEntry] {
        var path = "/audit_logs?limit=\(limit)"
        if let t = entityType { path += "&entityType=\(t)" }
        return try await get(path)
    }

    // MARK: - Consents

    func createConsent(_ payload: CreateConsentRequest) async throws -> ConsentSummary {
        return try await post("/consents", body: payload)
    }

    func getConsent(forSession sessionId: String) async throws -> ConsentSummary {
        return try await get("/sessions/\(sessionId)/consent")
    }

    func getConsentPDF(consentId: String) async throws -> Data {
        let resp: ConsentPDFResponse = try await get("/consents/\(consentId)/pdf")
        guard let data = Data(base64Encoded: resp.pdfB64) else {
            throw APIError.invalidResponse
        }
        return data
    }

    // MARK: - Route Optimization

    func optimizeRoute(sessions: [Session]) async throws -> OptimizedRouteResponse {
        return try await post("/optimize/routes", body: sessions)
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Diffusée par `APIService.intercept` lorsqu'un endpoint renvoie 401.
    /// `AuthViewModel` l'observe pour repasser sur l'écran de login.
    static let hcpilotSessionUnauthorized = Notification.Name("HCPilot.SessionUnauthorized")
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
