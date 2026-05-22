import Foundation

/// Validateurs réutilisables pour les formulaires (audit M1).
/// Centralise les règles métier — évite que chaque View réinvente la logique
/// et permet d'unitester les règles (Validators.isValidEmail, etc.).
enum Validators {

    // MARK: - Email

    /// Valide un email selon le pattern RFC 5322 simplifié.
    /// Pour un MVP : pas de DNS check, juste forme.
    static func isValidEmail(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Téléphone US

    /// Normalise les chiffres uniquement.
    static func normalizedDigits(_ s: String) -> String {
        s.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
            .map { String($0) }
            .joined()
    }

    /// Téléphone US valide :
    ///   - 10 chiffres (3-3-4)
    ///   - ou 11 chiffres commençant par 1 (avec country code US/Canada)
    static func isValidPhoneUS(_ s: String) -> Bool {
        let digits = normalizedDigits(s)
        if digits.count == 10 { return true }
        if digits.count == 11, digits.first == "1" { return true }
        return false
    }

    /// Formate "5551234567" → "(555) 123-4567" (brief : "formatage automatique
    /// format US"). Renvoie la string d'origine si pas un US phone valide.
    static func formattedPhoneUS(_ s: String) -> String {
        let d = normalizedDigits(s)
        let body: String
        switch d.count {
        case 10: body = d
        case 11 where d.first == "1": body = String(d.dropFirst())
        default: return s
        }
        let area = body.prefix(3)
        let mid = body.dropFirst(3).prefix(3)
        let end = body.dropFirst(6)
        return "(\(area)) \(mid)-\(end)"
    }

    // MARK: - Âge

    /// Renvoie true si la date de naissance correspond à un majeur (>= 18 ans).
    /// Brief : "DatePicker date de naissance (required, refuser <18 ans)".
    static func isAdult(dateOfBirth: Date, on referenceDate: Date = Date()) -> Bool {
        let comps = Calendar.current.dateComponents(
            [.year], from: dateOfBirth, to: referenceDate
        )
        return (comps.year ?? 0) >= 18
    }

    /// Idem mais avec une string ISO `yyyy-MM-dd`. Renvoie nil si la date est
    /// invalide (le caller peut alors traiter ça comme "à saisir").
    static func isAdult(dateOfBirthString: String, on referenceDate: Date = Date()) -> Bool? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let d = f.date(from: dateOfBirthString) else { return nil }
        return isAdult(dateOfBirth: d, on: referenceDate)
    }

    // MARK: - Licence

    /// Vérifie le format général d'un numéro de licence US :
    /// alphanum + tirets, au moins 4 caractères. Pas de validation au registre
    /// (chaque État a ses règles — vérifié à l'inscription humaine).
    static func isValidLicenseNumber(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 4 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Vérifie le format d'un code État US à 2 lettres (CA, TX, NY, ...).
    static func isValidStateCode(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count == 2 else { return false }
        return trimmed.unicodeScalars.allSatisfy { CharacterSet.uppercaseLetters.contains($0) }
    }

    // MARK: - NPI

    /// National Provider Identifier US : exactement 10 chiffres + Luhn check.
    /// Pour un MVP : on vérifie juste la longueur (Luhn = TODO).
    static func isValidNPI(_ s: String) -> Bool {
        normalizedDigits(s).count == 10
    }
}
