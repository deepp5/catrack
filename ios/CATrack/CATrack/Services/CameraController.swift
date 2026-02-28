import Foundation
import AVFoundation
import UIKit
import Combine

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var isRecording: Bool = false

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back

    private var recordingContinuation: CheckedContinuation<URL?, Never>?

    override init() {
        super.init()
        configure()
    }

    private func configure() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
                  let vInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(vInput) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(vInput)
            self.videoInput = vInput

            if let mic = AVCaptureDevice.default(for: .audio),
               let aInput = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(aInput) {
                self.session.addInput(aInput)
                self.audioInput = aInput
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()
        }
    }

    func start() {
        sessionQueue.async {
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func flip() {
        sessionQueue.async {
            self.currentPosition = (self.currentPosition == .back) ? .front : .back
            self.session.beginConfiguration()
            if let currentVideo = self.videoInput {
                self.session.removeInput(currentVideo)
            }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            self.videoInput = input
            self.session.commitConfiguration()
        }
    }

    func captureJPEG() async -> Data? {
        await withCheckedContinuation { cont in
            let settings = AVCapturePhotoSettings()
            // Fix: isHighResolutionPhotoEnabled deprecated in iOS 16 — use maxPhotoDimensions
            if #available(iOS 16.0, *) {
                if let format = photoOutput.availablePhotoPixelFormatTypes.first {
                    let dims = CMVideoDimensions(width: 4032, height: 3024)
                    settings.maxPhotoDimensions = dims
                }
            } else {
                settings.isHighResolutionPhotoEnabled = true
            }
            let delegate = PhotoDelegate { data in
                cont.resume(returning: data)
            }
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            objc_setAssociatedObject(self, UUID().uuidString, delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func startRecording() {
        sessionQueue.async {
            if self.movieOutput.isRecording { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("cattrack-\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: url)
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async { self.isRecording = true }
        }
    }

    func stopRecording() async -> URL? {
        await withCheckedContinuation { cont in
            sessionQueue.async {
                if !self.movieOutput.isRecording {
                    DispatchQueue.main.async { self.isRecording = false }
                    cont.resume(returning: nil)
                    return
                }
                self.recordingContinuation = cont
                self.movieOutput.stopRecording()
            }
        }
    }
}

// Fix: AVCaptureFileOutputRecordingDelegate must be nonisolated to avoid main-actor isolation conflict
extension CameraController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
        }

        if error != nil {
            recordingContinuation?.resume(returning: nil)
            recordingContinuation = nil
            return
        }

        recordingContinuation?.resume(returning: outputFileURL)
        recordingContinuation = nil
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let onData: (Data?) -> Void

    init(onData: @escaping (Data?) -> Void) {
        self.onData = onData
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        onData(error != nil ? nil : photo.fileDataRepresentation())
    }
}
