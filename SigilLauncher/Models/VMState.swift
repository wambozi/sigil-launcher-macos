import Foundation

/// Represents the lifecycle state of the NixOS virtual machine.
enum VMState: String, Equatable {
    case stopped
    case starting
    case running
    case stopping
    case error

    var displayName: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .stopping: return "Stopping..."
        case .error: return "Error"
        }
    }

    var isTransitioning: Bool {
        self == .starting || self == .stopping
    }
}
