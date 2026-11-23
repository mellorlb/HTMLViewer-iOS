import Foundation

enum ImportFailure: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self { case .failed(let reason): return reason }
    }
}

