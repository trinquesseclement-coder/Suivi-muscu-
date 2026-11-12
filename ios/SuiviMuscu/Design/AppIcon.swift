import SwiftUI

/// Toutes les icônes de l'appli passent par ici (images provisoires, remplacées au plan 3).
enum AppIcon: String, CaseIterable {
    case home, planning, add, load, machines, settings, sessions, time, timer, trophy, goal
    case together, wheelchair, transfer, standing, help, plate, cardio, sync, offline, photo, pyramid, play
    case back, more, check, close, minus, copy, rename, delete, classic, search

    var symbolName: String {
        switch self {
        case .home: "house"
        case .planning: "calendar"
        case .add: "plus"
        case .load: "chart.bar"
        case .machines: "dumbbell"
        case .settings: "gearshape"
        case .sessions: "figure.strengthtraining.traditional"
        case .time: "clock"
        case .timer: "timer"
        case .trophy: "trophy"
        case .goal: "target"
        case .together: "person.2"
        case .wheelchair: "figure.roll"
        case .transfer: "arrow.left.arrow.right"
        case .standing: "figure.stand"
        case .help: "hand.raised"
        case .plate: "circle.circle"
        case .cardio: "heart"
        case .sync: "arrow.triangle.2.circlepath"
        case .offline: "wifi.slash"
        case .photo: "camera"
        case .pyramid: "triangle"
        case .play: "play.fill"
        case .back: "chevron.left"
        case .more: "ellipsis"
        case .check: "checkmark"
        case .close: "xmark"
        case .minus: "minus"
        case .copy: "doc.on.doc"
        case .rename: "pencil"
        case .delete: "trash"
        case .classic: "equal"
        case .search: "magnifyingglass"
        }
    }

    var image: Image { Image(systemName: symbolName) }
}
