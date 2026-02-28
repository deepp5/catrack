import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

// MARK: - VoiceRecorderView
struct VoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    var onRecorded: (URL) -> Void

    @State private var isRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(isRecording ? Color.severityFail : Color.catYellow)
                    .animation(.easeInOut, value: isRecording)

                Text(isRecording ? "Recording..." : "Tap to Record")
                    .font(.headline)
                    .foregroundStyle(.white)

                Button(isRecording ? "Stop" : "Start Recording") {
                    isRecording.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(.catYellow)
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
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
