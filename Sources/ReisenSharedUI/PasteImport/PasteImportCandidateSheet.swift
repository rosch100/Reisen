import SwiftUI
import ReisenDomain

/// Kandidatenliste vor dem Editor — macOS und iOS teilen Inhalt und Feature-Button.
public struct PasteImportCandidateSheet: View {
    private let candidates: [PasteImportCandidate]
    private let canOfferFeatureRequest: Bool
    private let onCancel: () -> Void
    private let onContinue: () -> Void
    private let onRequestFeature: () -> Void

    public init(
        candidates: [PasteImportCandidate],
        canOfferFeatureRequest: Bool,
        onCancel: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onRequestFeature: @escaping () -> Void
    ) {
        self.candidates = candidates
        self.canOfferFeatureRequest = canOfferFeatureRequest
        self.onCancel = onCancel
        self.onContinue = onContinue
        self.onRequestFeature = onRequestFeature
    }

    private var presentation: PasteImportCandidateSheetPresentation {
        PasteImportCandidateSheetPresentation(
            candidateCount: candidates.count,
            canOfferFeatureRequest: canOfferFeatureRequest
        )
    }

    public var body: some View {
        #if os(macOS)
        macBody
        #else
        iosBody
        #endif
    }

    private var list: some View {
        PasteImportCandidateList(
            candidates: candidates,
            onRequestFeature: presentation.showsFeatureRequestButton ? onRequestFeature : nil
        )
    }

    #if os(macOS)
    private var macBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                list.frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(L10n.string(.commonCancel), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.string(.pasteImportContinue), action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!presentation.continueEnabled)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
    }
    #endif

    #if !os(macOS)
    private var iosBody: some View {
        NavigationStack {
            ScrollView {
                list
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.commonCancel), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.pasteImportContinue), action: onContinue)
                        .disabled(!presentation.continueEnabled)
                }
            }
        }
    }
    #endif
}
