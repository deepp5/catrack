import SwiftUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers
import Combine

// MARK: - CameraPickerView
struct CameraPickerView: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .camera
    var onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? sourceType : .photoLibrary
        return picker
    }
    //testing adding to github
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImagePicked: (UIImage) -> Void
        init(onImagePicked: @escaping (UIImage) -> Void) { self.onImagePicked = onImagePicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { onImagePicked(img) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - DocumentPickerView
struct DocumentPickerView: UIViewControllerRepresentable {
    var onFilePicked: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFilePicked: onFilePicked) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data, UTType.pdf, UTType.image], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onFilePicked: (URL) -> Void
        init(onFilePicked: @escaping (URL) -> Void) { self.onFilePicked = onFilePicked }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onFilePicked(url) }
        }
    }
}

// MARK: - AudioRecorderManager
class AudioRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordedURL: URL? = nil
    @Published var elapsedSeconds: Int = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: AnyCancellable?

    var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let fileName = "voice_\(formatter.string(from: Date())).m4a"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()

        isRecording = true
        elapsedSeconds = 0
        recordedURL = nil

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stopRecording() {
        recordedURL = audioRecorder?.url
        audioRecorder?.stop()
        timer?.cancel()
        isRecording = false
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { recordedURL = nil }
    }
}

// MARK: - VoiceRecorderView
struct VoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    var onRecorded: (URL, Int) -> Void  // URL + duration in seconds

    @StateObject private var recorder = AudioRecorderManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text(recorder.formattedTime)
                    .font(.dmMono(36))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(recorder.isRecording ? Color.severityFail : Color.catYellow)
                    .animation(.easeInOut, value: recorder.isRecording)

                Text(recorder.isRecording ? "Recording..." : "Tap to Record")
                    .font(.barlow(16))
                    .foregroundStyle(Color.appMuted)

                Button {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startRecording()
                    }
                } label: {
                    Text(recorder.isRecording ? "Stop" : "Start Recording")
                        .font(.barlow(16, weight: .semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.catYellow)

                if let url = recorder.recordedURL {
                    Button {
                        onRecorded(url, recorder.elapsedSeconds)
                        dismiss()
                    } label: {
                        Label("Use Recording", systemImage: "paperplane.fill")
                            .font(.barlow(15, weight: .semibold))
                            .foregroundStyle(Color.appBackground)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.catYellow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appMuted)
                }
            }
        }
    }
}

// MARK: - AudioPlayerManager
class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: CGFloat = 0

    private var player: AVAudioPlayer?
    private var timer: AnyCancellable?

    func togglePlayback(url: URL) {
        if isPlaying {
            player?.pause()
            timer?.cancel()
            isPlaying = false
        } else {
            if player == nil || player?.url != url {
                player = try? AVAudioPlayer(contentsOf: url)
                player?.delegate = self
            }
            player?.play()
            isPlaying = true
            timer = Timer.publish(every: 0.05, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self, let p = self.player else { return }
                    self.progress = CGFloat(p.currentTime / p.duration)
                }
        }
    }

    func formattedRemaining(total: Int) -> String {
        guard let p = player else { return "" }
        let remaining = Int(p.duration - p.currentTime)
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        timer?.cancel()
    }
}

// MARK: - VoiceNoteBubble
struct VoiceNoteBubble: View {
    let url: URL
    let duration: Int

    @StateObject private var player = AudioPlayerManager()

    var body: some View {
        HStack(spacing: 10) {
            Button {
                player.togglePlayback(url: url)
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.appBackground)
                    .frame(width: 36, height: 36)
                    .background(Color.catYellow)
                    .clipShape(Circle())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appBorder)
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.catYellow)
                        .frame(width: geo.size.width * player.progress, height: 4)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)

            Text(player.isPlaying ? player.formattedRemaining(total: duration) : formattedDuration)
                .font(.dmMono(11))
                .foregroundStyle(Color.appMuted)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 260)
    }

    var formattedDuration: String {
        String(format: "%d:%02d", duration / 60, duration % 60)
    }
}

