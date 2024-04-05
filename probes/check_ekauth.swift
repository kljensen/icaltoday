// This is a probe to check if the .fullAccess case is available in the EKAuthorizationStatus enum.
import EventKit

let status: EKAuthorizationStatus = .authorized // Dummy value for compilation

func isFullAccessAvailable() -> Bool {
    if #available(macOS 14, *) {
        return status == .authorized  || status == .fullAccess
    } else {
        return status == .authorized
    }
}

// Attempt to call the function (will fail on compilation if .fullAccess is not available)
_ = isFullAccessAvailable()
