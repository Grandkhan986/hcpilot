import Foundation
import UserNotifications

/// Service local pour les rappels conformité + rendez-vous.
/// Le brief prévoit ces notifications côté APNs + cron Supabase ; en attendant,
/// on les programme localement via `UNUserNotificationCenter` — l'app reprogramme
/// à chaque load (ComplianceVM / HomeVM) pour rester en phase avec les données.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Authorization

    /// Demande la permission (alert + badge + sound). Idempotent : si déjà accordée
    /// renvoie true sans re-prompter.
    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Compliance scheduling

    /// Brief §Notifications :
    ///   - Licence J-90, J-30, J-7, J-1
    ///   - Standing order J-30, J-7
    ///   - Contrat MD J-60, J-30, J-7
    ///   - Audit MD J-7 et jour J
    func scheduleComplianceNotifications(from dashboard: ComplianceDashboard) async {
        await removeScheduled(withPrefix: "compliance:")

        if let license = dashboard.license, let exp = license.expirationDate {
            let typeLabel = license.licenseType ?? "votre licence"
            for d in [90, 30, 7, 1] {
                await scheduleOnce(
                    id: "compliance:license:J-\(d)",
                    title: "Licence à renouveler",
                    body: "Votre licence \(typeLabel) (\(license.stateCode ?? "?")) expire dans \(d) jour\(d > 1 ? "s" : "").",
                    target: exp,
                    daysBefore: d
                )
            }
        }

        if let md = dashboard.medicalDirector, let mdEnd = md.contractEndDate {
            for d in [60, 30, 7] {
                await scheduleOnce(
                    id: "compliance:md:J-\(d)",
                    title: "Contrat Medical Director",
                    body: "Le contrat avec \(md.fullName) expire dans \(d) jour\(d > 1 ? "s" : "").",
                    target: mdEnd,
                    daysBefore: d
                )
            }
        }

        if let md = dashboard.medicalDirector, let auditDate = md.nextAuditDate {
            await scheduleOnce(
                id: "compliance:audit:J-7",
                title: "Audit MD à venir",
                body: "Préparer l'audit avec \(md.fullName) dans 7 jours.",
                target: auditDate,
                daysBefore: 7
            )
            await scheduleOnce(
                id: "compliance:audit:J-0",
                title: "Audit MD aujourd'hui",
                body: "Audit prévu avec \(md.fullName) aujourd'hui.",
                target: auditDate,
                daysBefore: 0
            )
        }

        for so in dashboard.standingOrders where so.isActive {
            if let exp = so.expiresAt {
                for d in [30, 7] {
                    await scheduleOnce(
                        id: "compliance:so:\(so.id):J-\(d)",
                        title: "Standing order à renouveler",
                        body: "\(so.formulationName) expire dans \(d) jour\(d > 1 ? "s" : "").",
                        target: exp,
                        daysBefore: d
                    )
                }
            }
        }
    }

    // MARK: - Session reminders

    /// J-1 et H-2 avant chaque session scheduled future.
    func scheduleSessionReminders(sessions: [Session]) async {
        await removeScheduled(withPrefix: "session:")
        let now = Date()
        for session in sessions where session.status == .scheduled {
            let target = session.scheduledAt
            guard target > now else { continue }

            // J-1 (à 8h le jour J-1)
            if let dayMinusOne = calendar.date(byAdding: .day, value: -1, to: target) {
                let dateAt8 = setHour(dayMinusOne, hour: 8)
                if dateAt8 > now {
                    await scheduleAt(
                        id: "session:\(session.id):J-1",
                        title: "RDV demain",
                        body: "\(session.clientName ?? "Client") à \(formatTime(target))",
                        fireDate: dateAt8
                    )
                }
            }

            // H-2 (2h avant le RDV)
            if let twoHoursBefore = calendar.date(byAdding: .hour, value: -2, to: target),
               twoHoursBefore > now {
                await scheduleAt(
                    id: "session:\(session.id):H-2",
                    title: "RDV dans 2 heures",
                    body: "\(session.clientName ?? "Client") à \(formatTime(target))",
                    fireDate: twoHoursBefore
                )
            }
        }
    }

    // MARK: - Inventory expiration (brief §Notifications)

    /// J-15 avant péremption d'un lot inventaire (brief §Stock et scan : "Alertes").
    /// Programme aussi J-30 pour les lots de gros volume (utile pour planifier
    /// les commandes). Bonus : un seul rappel par lot (id stable).
    func scheduleInventoryExpirationNotifications(lots: [InventoryLot]) async {
        await removeScheduled(withPrefix: "inventory:")
        let now = Date()
        for lot in lots where lot.quantityRemaining > 0 && lot.archivedAt == nil {
            let target = lot.expirationDate
            guard target > now else { continue }
            // J-30 + J-15 (brief : "J-15 avant péremption" + bon sens commande)
            for d in [30, 15] {
                guard let fireDate = calendar.date(byAdding: .day, value: -d, to: target) else { continue }
                let fireAt9 = setHour(fireDate, hour: 9)
                guard fireAt9 > now else { continue }
                await scheduleAt(
                    id: "inventory:\(lot.id):J-\(d)",
                    title: "Lot à renouveler",
                    body: "\(lot.productName) — Lot \(lot.lotNumber) expire dans \(d) jours (\(lot.quantityRemaining) restant\(lot.quantityRemaining > 1 ? "s" : "")).",
                    fireDate: fireAt9
                )
            }
        }
    }

    // MARK: - Inspection / test

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    func pendingByPrefix(_ prefix: String) async -> Int {
        let all = await center.pendingNotificationRequests()
        return all.filter { $0.identifier.hasPrefix(prefix) }.count
    }

    /// Pour QA : programme une notif dans X secondes.
    func scheduleSmokeTest() async {
        let content = UNMutableNotificationContent()
        content.title = "Test HCPilot"
        content.body = "Si tu vois ça, les notifications sont OK."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "smoketest:\(UUID().uuidString)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    func removeAll() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Helpers

    private func scheduleOnce(
        id: String, title: String, body: String, target: Date, daysBefore: Int
    ) async {
        guard let fireDate = calendar.date(byAdding: .day, value: -daysBefore, to: target) else { return }
        // Notification matinale (9h) pour éviter le bruit nocturne
        let fireAt9 = setHour(fireDate, hour: 9)
        guard fireAt9 > Date() else { return }
        await scheduleAt(id: id, title: title, body: body, fireDate: fireAt9)
    }

    private func scheduleAt(id: String, title: String, body: String, fireDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func removeScheduled(withPrefix prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func parseYMD(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: s)
    }

    private func setHour(_ date: Date, hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: date)
    }
}
