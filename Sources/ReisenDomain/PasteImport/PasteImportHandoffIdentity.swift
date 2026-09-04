/// SSOT für Share-Handoff-Identität (App Group, URL-Scheme). Entitlement-/Info-Plists spiegeln diese Werte.
///
/// Welche Variante aktiv ist, entscheidet der App-/Share-Target per `REISEN_IOS_PRIVATE`
/// (siehe `PasteImportHandoff` in `Apps/Shared`).
public enum PasteImportHandoffIdentity: Sendable {
    public static let storeAppGroup = "group.app.voyenna.reisen.pasteimport"
    public static let privateAppGroup = "group.app.voyenna.reisen.private.pasteimport"
    public static let storeURLScheme = "voyenna"
    public static let privateURLScheme = "voyenna-private"
    public static let urlHost = "paste-import"
}
