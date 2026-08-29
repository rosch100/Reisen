/// SSOT für Share-Handoff-Identität (App Group, URL-Scheme). Entitlement-/Info-Plists spiegeln diese Werte.
///
/// Welche Variante aktiv ist, entscheidet der App-/Share-Target per `REISEN_IOS_PRIVATE`
/// (siehe `PasteImportHandoff` in `Apps/Shared`).
public enum PasteImportHandoffIdentity: Sendable {
    public static let storeAppGroup = "group.de.reisen.Reisen.pasteimport"
    public static let privateAppGroup = "group.de.reisen.Reisen.private.pasteimport"
    public static let storeURLScheme = "reisen"
    public static let privateURLScheme = "reisen-private"
    public static let urlHost = "paste-import"
}
