import Foundation

enum RemoteOption: String, CaseIterable, Codable {
    case onSite = "On-Site"
    case remote = "Remote"
    case hybrid = "Hybrid"
    
    var icon: String {
        switch self {
        case .onSite: return "building.2"
        case .remote: return "house"
        case .hybrid: return "arrow.left.arrow.right"
        }
    }
}
