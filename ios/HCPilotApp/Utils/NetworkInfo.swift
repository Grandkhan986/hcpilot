import Foundation
import Darwin

/// Local network helpers used to enrich audit/consent metadata.
/// Capturing the device IP at signature time is required for HIPAA-grade
/// forensic auditability (cf. brief §Compliance + audit H23).
enum NetworkInfo {
    /// Returns the device's IPv4 address on the active non-loopback interface,
    /// preferring Wi-Fi (`en0`) then cellular (`pdp_ip0`). Returns nil if no
    /// interface is up — the PDF builder will then omit the IP line rather
    /// than print a placeholder.
    static func currentIPAddress() -> String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        let preferred = ["en0", "pdp_ip0"]
        var fallback: String?

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = Int32(cur.pointee.ifa_flags)
            // up + running + not loopback
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0 else { continue }

            let name = String(cString: cur.pointee.ifa_name)
            var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let status = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &buf,
                socklen_t(buf.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard status == 0 else { continue }
            let ip = String(cString: buf)
            if preferred.contains(name) { return ip }
            if fallback == nil { fallback = ip }
        }
        return fallback
    }
}
