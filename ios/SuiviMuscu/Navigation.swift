import SwiftUI

/// Une séance à ouvrir, avec la carte d'où elle part (transition « zoom » d'iOS 18).
struct SessionRoute: Hashable {
    let id: String
    /// Identifiant de la vue source marquée par `zoomSource`.
    let source: String
    /// Séance libre créée par « + » : supprimée si on la quitte sans rien y mettre.
    var fresh = false
}

extension View {
    /// Marque la vue comme point de départ du zoom vers une séance.
    @ViewBuilder func zoomSource(_ id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
