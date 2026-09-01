import SwiftUI

struct PermissionDeniedView: View {
    let permissionType: PermissionType
    let onOpenSettings: () -> Void

    enum PermissionType {
        case camera
        case microphone
        case photoLibrary

        var title: String {
            switch self {
            case .camera: return "Izin Kamera Diperlukan"
            case .microphone: return "Izin Mikrofon Diperlukan"
            case .photoLibrary: return "Izin Photo Library Diperlukan"
            }
        }

        var message: String {
            switch self {
            case .camera:
                return "Aplikasi memerlukan akses ke kamera untuk mengambil foto dan video secara hands-free."
            case .microphone:
                return "Aplikasi memerlukan akses ke mikrofon untuk merekam audio saat perekaman video."
            case .photoLibrary:
                return "Aplikasi memerlukan akses ke photo library untuk menyimpan hasil rekaman."
            }
        }

        var iconName: String {
            switch self {
            case .camera: return "camera.fill"
            case .microphone: return "mic.fill"
            case .photoLibrary: return "photo.on.rectangle"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: permissionType.iconName)
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text(permissionType.title)
                    .font(.system(.title, weight: .black))

                Text(permissionType.message)
                    .font(.system(.body))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    onOpenSettings()
                } label: {
                    Text("Buka Pengaturan")
                        .font(.system(.headline, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

#Preview {
    PermissionDeniedView(permissionType: .camera) {}
}
