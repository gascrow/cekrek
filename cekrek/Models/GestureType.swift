import Foundation

enum GestureType: String, CaseIterable, Codable {
    case openPalm
    case closedFist
    case peaceSign
    case crossedHands

    var displayName: String {
        switch self {
        case .openPalm: return "Telapak Terbuka"
        case .closedFist: return "Kepalan Tangan"
        case .peaceSign: return "Victory / V Sign"
        case .crossedHands: return "Silangan / X Sign"
        }
    }

    var iconName: String {
        switch self {
        case .openPalm: return "hand.raised.fill"
        case .closedFist: return "hand.raised.fist.fill"
        case .peaceSign: return "hand.thumbsup.fill"
        case .crossedHands: return "xmark.circle.fill"
        }
    }

    func action(for mode: CaptureMode) -> GestureAction {
        switch (self, mode) {
        case (.openPalm, .video): return .startRecording
        case (.openPalm, .photo): return .singleCapture
        case (.closedFist, .video): return .stopRecording
        case (.closedFist, .photo): return .cancelCountdown
        case (.peaceSign, .video): return .switchCamera
        case (.peaceSign, .photo): return .burstShot
        case (.crossedHands, .video): return .deleteLastTake
        case (.crossedHands, .photo): return .none
        }
    }
}

enum GestureAction: String, Codable {
    case startRecording
    case stopRecording
    case switchCamera
    case deleteLastTake
    case singleCapture
    case cancelCountdown
    case burstShot
    case none

    var displayName: String {
        switch self {
        case .startRecording: return "Mulai Rekam"
        case .stopRecording: return "Stop & Simpan"
        case .switchCamera: return "Ganti Kamera"
        case .deleteLastTake: return "Hapus Rekaman Terakhir"
        case .singleCapture: return "Ambil Foto"
        case .cancelCountdown: return "Batalkan Countdown"
        case .burstShot: return "Burst Shot (3 Foto)"
        case .none: return "Tidak Ada"
        }
    }
}
