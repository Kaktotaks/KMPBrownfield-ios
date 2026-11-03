import SwiftUI

// GENERATED from the shared icon table (same path data as Android `TasksIcons`): 24 grid, stroke 2.2,
// round caps. Do not edit by hand.

enum TKIconName: String {
    case search
    case sort
    case chevronDown
    case clock
    case calendar
    case flag
    case check
    case checkBold
    case plus
    case plusBold
    case pencil
    case trash
    case refresh
    case alert
    case close
    case statusRing
    case listChecks
    case barChart

    /// Stroke width in 24-grid units.
    var strokeWidth: CGFloat {
        switch self {
        case .checkBold: return 3.2
        case .plusBold: return 2.6
        default: return 2.2
        }
    }

    var paths: [String] {
        switch self {
        case .search: return [
            "M18 11 C18 14.866 14.866 18 11 18 C7.134 18 4 14.866 4 11 C4 7.134 7.134 4 11 4 C14.866 4 18 7.134 18 11 Z",
            "M16.65 16.65 L21 21"]
        case .sort: return [
            "M13 16 L17 20 L21 16",
            "M17 20 L17 4",
            "M3 8 L7 4 L11 8",
            "M7 4 L7 20"]
        case .chevronDown: return [
            "M6 9 L12 15 L18 9"]
        case .clock: return [
            "M22 12 C22 17.523 17.523 22 12 22 C6.477 22 2 17.523 2 12 C2 6.477 6.477 2 12 2 C17.523 2 22 6.477 22 12 Z",
            "M12 6 L12 12 L16 14"]
        case .calendar: return [
            "M5 4 L19 4 C20.105 4 21 4.895 21 6 L21 20 C21 21.105 20.105 22 19 22 L5 22 C3.895 22 3 21.105 3 20 L3 6 C3 4.895 3.895 4 5 4 Z",
            "M16 2 L16 6",
            "M8 2 L8 6",
            "M3 10 L21 10"]
        case .flag: return [
            "M4 15 C4 15 5 14 8 14 C11 14 13 16 16 16 C19 16 20 15 20 15 L20 3 C20 3 19 4 16 4 C13 4 11 2 8 2 C5 2 4 3 4 3 Z",
            "M4 22 L4 15"]
        case .check: return [
            "M20 6 L9 17 L4 12"]
        case .checkBold: return [
            "M20 6 L9 17 L4 12"]
        case .plus: return [
            "M5 12 L19 12",
            "M12 5 L12 19"]
        case .plusBold: return [
            "M5 12 L19 12",
            "M12 5 L12 19"]
        case .pencil: return [
            "M16.5 3.5 L20.5 7.5 L8 20 L3 21 L4 16 Z",
            "M14 6 L18 10"]
        case .trash: return [
            "M3 6 L21 6",
            "M19 6 L18 20 C18 21 17 22 16 22 L8 22 C7 22 6 21 6 20 L5 6",
            "M8 6 L8 4 C8 3 9 2 10 2 L14 2 C15 2 16 3 16 4 L16 6",
            "M10 11 L10 17",
            "M14 11 L14 17"]
        case .refresh: return [
            "M21 12 C21 16.97 16.97 21 12 21 C7.03 21 3 16.97 3 12 C3 7.03 7.03 3 12 3 C14.52 3 16.93 4 18.74 5.74 L21 8",
            "M21 3 L21 8 L16 8"]
        case .alert: return [
            "M22 12 C22 17.523 17.523 22 12 22 C6.477 22 2 17.523 2 12 C2 6.477 6.477 2 12 2 C17.523 2 22 6.477 22 12 Z",
            "M12 8 L12 12",
            "M12 16 L12.01 16"]
        case .close: return [
            "M18 6 L6 18",
            "M6 6 L18 18"]
        case .statusRing: return [
            "M21 12 C21 16.971 16.971 21 12 21 C7.029 21 3 16.971 3 12 C3 7.029 7.029 3 12 3 C16.971 3 21 7.029 21 12 Z"]
        case .listChecks: return [
            "M3 17 L5 19 L9 15",
            "M3 7 L5 9 L9 5",
            "M13 6 L21 6",
            "M13 12 L21 12",
            "M13 18 L21 18"]
        case .barChart: return [
            "M12 20 L12 10",
            "M18 20 L18 4",
            "M6 20 L6 16"]
        }
    }
}
