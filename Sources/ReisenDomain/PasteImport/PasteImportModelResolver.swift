/// Wählt das Extraktions-Modell allein aus der Verfügbarkeit.
///
/// Private Cloud Compute hat Vorrang, weil es die größeren Eingaben verarbeitet.
/// Der Resolver kennt nur Verfügbarkeiten, keine Laufzeitfehler — ein Wechsel
/// nach einem fehlgeschlagenen Lauf ist damit ausdrücklich nicht seine Aufgabe.
public enum PasteImportModelResolver {
    public static func resolve(_ availability: PasteImportModelAvailability) -> PasteImportModelKind {
        if availability.privateCloudCompute { return .privateCloudCompute }
        if availability.onDevice { return .onDevice }
        return .unavailable
    }
}
