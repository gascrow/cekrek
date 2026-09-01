import Foundation

enum CaptureMode: String, CaseIterable, Codable {
    case video
    case photo

    var displayName: String {
        switch self {
        case .video: return "Video"
        case .photo: return "Foto"
        }
    }

    var accentColor: String {
        switch self {
        case .video: return "videoAccent"
        case .photo: return "photoAccent"
        }
    }
}
