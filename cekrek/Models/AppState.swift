import Foundation

enum GestureState: Equatable {
    case idle
    case holding(progress: Double)
    case triggered
    case cooldown

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .holding: return "Menahan..."
        case .triggered: return "Tercetus!"
        case .cooldown: return "Cooldown"
        }
    }
}

enum AppError: Error, LocalizedError {
    case cameraPermissionDenied
    case microphonePermissionDenied
    case photoLibraryPermissionDenied
    case lowStorage
    case thermalCritical
    case cameraSwitchDuringRecording
    case captureFailed
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Izin kamera ditolak. Aktifkan di Pengaturan iOS."
        case .microphonePermissionDenied:
            return "Izin mikrofon ditolak. Aktifkan di Pengaturan iOS."
        case .photoLibraryPermissionDenied:
            return "Izin akses foto ditolak. Aktifkan di Pengaturan iOS."
        case .lowStorage:
            return "Ruang penyimpanan tersisa kurang dari 500MB."
        case .thermalCritical:
            return "Perangkat terlalu panas. Rekaman dihentikan untuk mencegah kerusakan."
        case .cameraSwitchDuringRecording:
            return "Tidak dapat mengganti kamera saat merekam."
        case .captureFailed:
            return "Gagal mengambil foto."
        case .recordingFailed:
            return "Gagal merekam video."
        }
    }
}
