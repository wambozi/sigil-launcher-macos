import Foundation

/// Represents the lifecycle state of the NixOS virtual machine.
public enum VMState: String, Equatable {
    case stopped
    case starting
    case running
    case stopping
    case error

    public var displayName: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .stopping: return "Stopping..."
        case .error: return "Error"
        }
    }

    public var isTransitioning: Bool {
        self == .starting || self == .stopping
    }
}
