import Foundation
import UIKit

final class CrashRecoveryManager {
    static let shared = CrashRecoveryManager()

    private let recoveredFilesKey = "recoveredRecordingURLs"
    private let crashTimestampKey = "lastCrashTimestamp"

    private init() {
        registerAppTermination()
    }

    // MARK: - Save Crash State

    func saveRecordingInProgress(url: URL) {
        var urls = getRecoveredURLs()
        urls.append(url.absoluteString)
        UserDefaults.standard.set(urls, forKey: recoveredFilesKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: crashTimestampKey)
    }

    func removeRecordingInProgress(url: URL) {
        var urls = getRecoveredURLs()
        urls.removeAll { $0 == url.absoluteString }
        UserDefaults.standard.set(urls, forKey: recoveredFilesKey)
    }

    func clearAllCrashData() {
        UserDefaults.standard.removeObject(forKey: recoveredFilesKey)
        UserDefaults.standard.removeObject(forKey: crashTimestampKey)

        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.contains("cekrek_temp") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Recovery

    func getRecoveredURLs() -> [String] {
        UserDefaults.standard.stringArray(forKey: recoveredFilesKey) ?? []
    }

    func hasRecoverableRecordings() -> Bool {
        let urls = getRecoveredURLs()
        guard !urls.isEmpty else { return false }

        let validURLs = urls.compactMap { URL(string: $0) }.filter { url in
            FileManager.default.fileExists(atPath: url.path)
        }

        return !validURLs.isEmpty
    }

    func recoverRecordings() async -> [(url: URL, success: Bool)] {
        let urls = getRecoveredURLs().compactMap { URL(string: $0) }
        var results: [(url: URL, success: Bool)] = []

        for url in urls {
            if FileManager.default.fileExists(atPath: url.path) {
                let success = await StorageManager.shared.saveVideo(at: url)
                results.append((url: url, success: success))
            }
        }

        clearAllCrashData()
        return results
    }

    // MARK: - App Lifecycle

    private func registerAppTermination() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func appWillTerminate() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: crashTimestampKey)
    }

    @objc private func appDidEnterBackground() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: crashTimestampKey)
    }
}
