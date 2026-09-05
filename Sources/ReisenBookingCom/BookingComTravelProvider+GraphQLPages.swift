import Foundation
import ReisenProviders
import ReisenDiagnostics
import ReisenDomain

@MainActor
extension BookingComTravelProvider {
    func fetchTripIDsForStageGroup(
        stages: [String],
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        parser: BookingComTripsGraphQLParser,
        seen: inout Set<String>
    ) async throws -> [String] {
        var orderedIDs: [String] = []
        do {
            var paginationToken: String? = nil
            repeat {
                let page = try await fetchTripIDsPage(
                    using: webView,
                    tokens: tokens,
                    stages: stages,
                    paginationToken: paginationToken
                )
                appendUnseenTripIDs(page.tripIDs, into: &orderedIDs, seen: &seen)
                paginationToken = page.nextPaginationToken
            } while paginationToken != nil
        } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
            throw BookingComProviderError.sessionNotEstablished
        } catch let error as BookingComProviderError {
            switch error {
            case .sessionNotEstablished, .sessionTokensMissing:
                throw error
            case .catalogNotFound:
                Self.recordStageTripIDsSkipped(stages: stages, error: error)
            }
        } catch {
            Self.recordStageTripIDsSkipped(stages: stages, error: error)
        }
        return orderedIDs
    }

    func appendUnseenTripIDs(
        _ tripIDs: [String],
        into orderedIDs: inout [String],
        seen: inout Set<String>
    ) {
        for id in tripIDs where !seen.contains(id) {
            seen.insert(id)
            orderedIDs.append(id)
        }
    }

    func fetchTripIDsPage(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        stages: [String],
        paginationToken: String?
    ) async throws -> (tripIDs: [String], nextPaginationToken: String?) {
        let json = try await fetchGetTripsGraphQL(
            using: webView,
            tokens: tokens,
            stages: stages,
            paginationToken: paginationToken
        )
        let parser = BookingComTripsGraphQLParser()
        let tripIDs = try parser.parseTripIDs(fromGetTripsJSON: json)
        let nextPaginationToken = try parser.parsePaginationToken(fromGetTripsJSON: json)
        return (tripIDs, nextPaginationToken)
    }

    private static func recordStageTripIDsSkipped(stages: [String], error: Error) {
        let stageLabel = stages.joined(separator: ",").prefix(64)
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .booking,
                        operation: "booking_com_catalog"
                    ),
                    component: "BookingComTravelProvider",
                    phase: "get_trips_stages",
                    event: "stage_trip_ids_skipped",
                    result: .skipped,
                    errorType: String(describing: type(of: error)),
                    reason: String(stageLabel),
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
