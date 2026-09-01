import Photos
import UIKit
import Combine

final class StorageManager: ObservableObject {
    static let shared = StorageManager()

    @Published var hasPermission = false

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }

    // MARK: - Album

    func findOrCreateAlbum(named name: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title == %@", name)

        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let album = collections.firstObject {
            return album
        }

        var albumPlaceholder: PHObjectPlaceholder?
        var createdAlbum: PHAssetCollection?

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            albumPlaceholder = request.placeholderForCreatedAssetCollection
        }, completionHandler: { success, _ in
            guard success, let placeholder = albumPlaceholder else { return }

            let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
            createdAlbum = result.firstObject
        })

        Thread.sleep(forTimeInterval: 0.5)
        return createdAlbum
    }

    // MARK: - Save Photo

    func savePhoto(_ image: UIImage) async -> Bool {
        guard let album = findOrCreateAlbum(named: Constants.albumName) else { return false }

        var assetPlaceholder: PHObjectPlaceholder?

        let success = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                guard let placeholder = assetRequest.placeholderForCreatedAsset,
                      let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else { return }
                albumChangeRequest.addAssets([placeholder] as NSArray)
            }) { result, _ in
                continuation.resume(returning: result)
            }
        }

        return success
    }

    func saveBurstPhotos(_ images: [UIImage]) async -> Bool {
        guard let album = findOrCreateAlbum(named: Constants.albumName), !images.isEmpty else { return false }

        let success = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                for image in images {
                    let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    guard let placeholder = assetRequest.placeholderForCreatedAsset else { continue }
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
                }
            }) { result, _ in
                continuation.resume(returning: result)
            }
        }

        return success
    }

    // MARK: - Save Video

    func saveVideo(at url: URL) async -> Bool {
        guard let album = findOrCreateAlbum(named: Constants.albumName) else { return false }

        let success = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                guard let placeholder = assetRequest?.placeholderForCreatedAsset else { return }
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
            }) { result, _ in
                continuation.resume(returning: result)
            }
        }

        if success {
            try? FileManager.default.removeItem(at: url)
        }

        return success
    }

    // MARK: - Storage Check

    func checkAvailableStorageMB() -> Int64 {
        guard let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSize = systemAttributes[.systemFreeSize] as? Int64 else {
            return 0
        }
        return freeSize / (1024 * 1024)
    }

    var hasEnoughStorage: Bool {
        checkAvailableStorageMB() > Int64(Constants.minStorageWarningMB)
    }
}
