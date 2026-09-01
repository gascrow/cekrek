import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: CaptureMode = .video

    var body: some View {
        NavigationStack {
            List {
                cameraSection
                gestureSection
                gestureMappingSection
                recordingSection
                feedbackSection
            }
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Selesai") {
                        dismiss()
                    }
                    .font(.system(.headline, weight: .heavy))
                }
            }
        }
    }

    // MARK: - Camera Section

    private var cameraSection: some View {
        Section {
            Picker("Resolusi Video", selection: $settingsStore.preferredResolution) {
                Text("1080p 30 FPS").tag("1080p_30")
                Text("1080p 60 FPS").tag("1080p_60")
                Text("4K 30 FPS").tag("4K_30")
                Text("4K 60 FPS").tag("4K_60")
            }
            .pickerStyle(.inline)
        } header: {
            Text("Kamera")
        } footer: {
            Text("Resolusi default saat merekam video.")
        }
    }

    // MARK: - Gesture Section

    private var gestureSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Durasi Hold Gestur")
                    .font(.system(.body, weight: .semibold))

                HStack {
                    Text("0.5s")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.gray)

                    Slider(value: $settingsStore.gestureHoldDuration, in: 0.5...1.5, step: 0.1)
                        .tint(.blue)

                    Text("1.5s")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.gray)
                }

                Text(String(format: "%.1f detik", settingsStore.gestureHoldDuration))
                    .font(.system(.title2, weight: .black))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Ambang Confidence")
                    .font(.system(.body, weight: .semibold))

                HStack {
                    Text("0.5")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.gray)

                    Slider(value: $settingsStore.confidenceThreshold, in: 0.5...1.0, step: 0.05)
                        .tint(.green)

                    Text("1.0")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.gray)
                }

                Text(String(format: "%.2f", settingsStore.confidenceThreshold))
                    .font(.system(.title2, weight: .black))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Gestur")
        } footer: {
            Text("Durasi hold menentukan berapa lama gestur harus ditahan sebelum aksi terpicu. Confidence threshold menentukan seberapa yakin sistem terhadap gestur.")
        }
    }

    // MARK: - Gesture Mapping Section

    private var gestureMappingSection: some View {
        Section {
            Picker("Mode", selection: $selectedMode) {
                ForEach(CaptureMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            ForEach(GestureType.allCases, id: \.rawValue) { gesture in
                GestureMappingRow(
                    gesture: gesture,
                    mode: selectedMode,
                    settingsStore: settingsStore
                )
            }
        } header: {
            Text("Pemetaan Gestur Kustom")
        } footer: {
            Text("Ubah aksi yang dipicu oleh setiap gestur di mode yang dipilih.")
        }
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Batas Rekaman")
                    .font(.system(.body, weight: .semibold))

                Picker("Batas Rekaman", selection: $settingsStore.maxRecordingDurationSeconds) {
                    Text("1 Menit").tag(60)
                    Text("3 Menit").tag(180)
                    Text("5 Menit").tag(300)
                    Text("10 Menit").tag(600)
                }
                .pickerStyle(.inline)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Perekaman")
        } footer: {
            Text("Durasi maksimum per sesi rekaman video.")
        }
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        Section {
            Toggle("Haptic Feedback", isOn: $settingsStore.hapticFeedbackEnabled)
                .font(.system(.body, weight: .semibold))

            Toggle("Efek Suara", isOn: $settingsStore.soundEffectsEnabled)
                .font(.system(.body, weight: .semibold))
        } header: {
            Text("Umpan Balik")
        } footer: {
            Text("Haptic feedback bergetar saat gestur terdeteksi. Efek suara memutar suara shutter dan beep.")
        }
    }
}

// MARK: - Gesture Mapping Row

struct GestureMappingRow: View {
    let gesture: GestureType
    let mode: CaptureMode
    @ObservedObject var settingsStore: SettingsStore

    private var availableActions: [GestureAction] {
        switch mode {
        case .video:
            return [.startRecording, .stopRecording, .switchCamera, .deleteLastTake, .none]
        case .photo:
            return [.singleCapture, .cancelCountdown, .burstShot, .none]
        }
    }

    var body: some View {
        HStack {
            Image(systemName: gesture.iconName)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(gesture.displayName)
                    .font(.system(.body, weight: .semibold))

                Text(mode.displayName)
                    .font(.system(.caption))
                    .foregroundStyle(.gray)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { settingsStore.customAction(for: gesture, in: mode) },
                set: { settingsStore.setCustomAction($0, for: gesture, in: mode) }
            )) {
                ForEach(availableActions, id: \.rawValue) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(settingsStore: SettingsStore.shared)
}
