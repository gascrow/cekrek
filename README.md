# Cekrek - AI Hands-Free Camera

Aplikasi kamera hands-free untuk solo creator yang menggunakan gestur tangan untuk mengontrol kamera tanpa menyentuh layar.

## Persyaratan

- macOS dengan Xcode 15.0+
- iOS 17.0+
- iPhone dengan chip A14 Bionic ke atas (iPhone 12+)

## Setup Xcode Project

1. Buka Xcode → File → New → Project
2. Pilih **iOS → App**
3. Product Name: **cekrek**
4. Interface: **SwiftUI**
5. Language: **Swift**
6. Storage: **None**
7. Save project di folder `/Users/bagasxy/cekrek/`
8. Hapus file `cekrekApp.swift` dan `ContentView.swift` yang dibuat otomatis oleh Xcode
9. Drag folder `cekrek/` (semua source files) ke project navigator Xcode
10. Pastikan semua file sudah ter-*check* di target **cekrek**
11. Di Info.plist, pastikan keys berikut sudah ada (sudah disediakan di `Resources/Info.plist`):
    - `NSCameraUsageDescription`
    - `NSMicrophoneUsageDescription`
    - `NSPhotoLibraryUsageDescription`

## Struktur Project

```
cekrek/
├── App/
│   └── CekrekApp.swift          # Entry point
├── Views/
│   ├── CameraView.swift          # UI kamera utama
│   └── SettingsView.swift        # Halaman pengaturan
├── ViewModels/
│   └── CameraViewModel.swift     # ViewModel untuk kamera
├── Services/
│   ├── CameraSessionManager.swift  # AVFoundation pipeline
│   ├── StorageManager.swift        # PhotoKit save
│   ├── SettingsStore.swift         # UserDefaults wrapper
│   └── AudioHapticManager.swift    # Audio & haptic feedback
├── Models/
│   ├── GestureType.swift         # Enum gestur & aksi
│   ├── CaptureMode.swift         # Enum mode video/foto
│   └── AppState.swift            # State & error definitions
├── Utilities/
│   └── Constants.swift           # Konstanta aplikasi
└── Resources/
    ├── Info.plist                # Privacy keys
    └── Assets.xcassets/          # Warna & ikon
```

## Fitur Sprint 1

- ✅ Preview kamera real-time (depan/belakang)
- ✅ Toggle mode Video/Foto
- ✅ Capture foto (single)
- ✅ Burst shot (3 foto)
- ✅ Rekam video dengan durasi maksimum
- ✅ Auto-save ke album "AI Hands-Free" di Photos Library
- ✅ Switch kamera (depan ↔ belakang)
- ✅ Countdown 3 detik sebelum capture
- ✅ Flash effect saat foto diambil
- ✅ Haptic feedback
- ✅ Settings: durasi hold, confidence threshold, resolusi, haptic, suara
- ✅ Penanganan error (izin ditolak, storage penuh, dll)
- ✅ Peringatan 30 detik sebelum batas rekaman tercapai
- ✅ Temp buffer untuk crash recovery

## Build & Run

1. Pilih device fisik atau simulator
2. Tekan **Cmd + R** untuk build dan run
3. Izinkan akses kamera, mikrofon, dan photo library saat diminta

## Catatan

- Gesture detection (Vision Framework) akan diimplementasikan di Sprint 2
- UI menggunakan gaya Neo-Brutalist: kontras tinggi, tipografi tebal
- Semua pemrosesan dilakukan di-device (tidak ada backend)
