import Foundation
import CoreLocation

/// One-shot location capture pour la signature de consentement.
/// Demande la permission `When In Use` si nécessaire, puis renvoie la
/// dernière position connue. Non-bloquant : si l'utilisateur refuse ou
/// si CL échoue, on renvoie nil (le consentement est tout de même signable).
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published private(set) var lastCoordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private var pendingContinuations: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []

    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Demande la permission + une localisation. Renvoie nil si refusé ou échec.
    func requestOneShot() async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { cont in
            pendingContinuations.append(cont)
            switch authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                resolveAll(with: nil)
            }
        }
    }

    private func resolveAll(with coord: CLLocationCoordinate2D?) {
        let conts = pendingContinuations
        pendingContinuations.removeAll()
        for c in conts { c.resume(returning: coord) }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                resolveAll(with: nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        Task { @MainActor in
            self.lastCoordinate = coord
            resolveAll(with: coord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            resolveAll(with: nil)
        }
    }
}
