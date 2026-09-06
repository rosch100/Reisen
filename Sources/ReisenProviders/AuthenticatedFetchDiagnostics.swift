import Foundation
import ReisenDiagnostics

/// DiagnosticEvents für authentifizierte Abrufe (Start/Erfolg/Timeout).
public enum AuthenticatedFetchDiagnostics {
    public static let component = "AuthenticatedFetch"
    public static let phase = "authenticated_fetch"

    public static func event(
        context: DiagnosticContext,
        event: String,
        result: DiagnosticResult,
        url: URL?,
        durationMilliseconds: Int? = nil,
        reason: String? = nil,
        errorType: String? = nil
    ) -> DiagnosticEvent {
        DiagnosticEvent(
            context: context,
            component: component,
            phase: phase,
            event: event,
            result: result,
            durationMilliseconds: durationMilliseconds,
            url: url?.absoluteString,
            errorType: errorType,
            reason: reason
        )
    }
}
