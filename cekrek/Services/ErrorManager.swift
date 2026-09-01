import Foundation

protocol ErrorManagerDelegate: AnyObject {
    func errorManager(_ manager: ErrorManager, didEncounterError error: AppError)
    func errorManager(_ manager: ErrorManager, didRequestPermissionFor type: ErrorManager.PermissionType)
}

final class ErrorManager {
    enum PermissionType {
        case camera
        case microphone
        case photoLibrary
    }

    weak var delegate: ErrorManagerDelegate?

    private var errorLog: [(error: AppError, timestamp: Date)] = []

    func handle(_ error: AppError) {
        errorLog.append((error: error, timestamp: Date()))
        delegate?.errorManager(self, didEncounterError: error)
    }

    func handlePermissionDenied(for type: PermissionType) {
        delegate?.errorManager(self, didRequestPermissionFor: type)
    }

    func getErrorLog() -> [(error: AppError, timestamp: Date)] {
        errorLog
    }

    func clearLog() {
        errorLog.removeAll()
    }

    func isRecoverable(_ error: AppError) -> Bool {
        switch error {
        case .cameraPermissionDenied, .microphonePermissionDenied, .photoLibraryPermissionDenied:
            return true
        case .thermalCritical:
            return false
        case .lowStorage:
            return true
        case .cameraSwitchDuringRecording:
            return false
        case .captureFailed, .recordingFailed:
            return true
        }
    }

    func suggestedAction(for error: AppError) -> String {
        switch error {
        case .cameraPermissionDenied:
            return "Aktifkan akses kamera di Pengaturan iOS."
        case .microphonePermissionDenied:
            return "Aktifkan akses mikrofon di Pengaturan iOS."
        case .photoLibraryPermissionDenied:
            return "Aktifkan akses photo library di Pengaturan iOS."
        case .lowStorage:
            return "Hapus beberapa file untuk membebaskan ruang penyimpanan."
        case .thermalCritical:
            return "Tunggu perangkat mendingin sebelum melanjutkan."
        case .cameraSwitchDuringRecording:
            return "Hentikan rekaman terlebih dahulu sebelum mengganti kamera."
        case .captureFailed:
            return "Coba ambil foto lagi."
        case .recordingFailed:
            return "Coba rekam ulang video."
        }
    }
}
