import SwiftUI

/// Une séance à ouvrir, avec la carte d'où elle part (transition « zoom » d'iOS 18).
struct SessionRoute: Hashable {
    let id: String
    /// Identifiant de la vue source marquée par `zoomSource`.
    let source: String
    /// Séance libre créée par « + » : supprimée si on la quitte sans rien y mettre.
    var fresh = false
}

/// L'éditeur de séance planifiée : une séance existante (`sessionId`) ou une nouvelle, à `date`.
struct PlanRoute: Hashable {
    var sessionId: String?
    var date: String?
}

/// Les Réglages, poussés sur la pile comme les autres écrans (un lien poussé depuis une destination
/// `isPresented` ne s'ouvrait pas : tout passe par `path`).
struct SettingsRoute: Hashable {
    /// Carte amenée en haut à l'ouverture (`nil` : le haut des Réglages).
    var focus: SettingsFocus?
}

/// L'éditeur d'une séance type du cycle (`templateId == nil` : une nouvelle).
struct CycleRoute: Hashable {
    var templateId: String?
}

/// Ouvre l'éditeur d'une séance type (`nil` : une nouvelle) ; ne fait rien si un écran est déjà
/// poussé par-dessus les Réglages.
struct OpenCycleTemplateAction {
    var run: (String?) -> Void = { _ in }
    func callAsFunction(_ templateId: String?) { run(templateId) }
}

extension EnvironmentValues {
    @Entry var openCycleTemplate = OpenCycleTemplateAction()
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
