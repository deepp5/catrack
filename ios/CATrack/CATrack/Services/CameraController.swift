import Foundation
import AVFoundation
import UIKit
import Combine

private final class ContinuationBox: @unchecked Sendable {
    var value: CheckedContinuation<URL?, Never>?
}

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var isRecording: Bool = false
    @Published var isSessionReady: Bool = false

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back

    private let recordingBox = ContinuationBox()
    private var inFlightPhotoDelegate: PhotoDelegate?

    override init() {
        super.init()
        // IMPORTANT: We intentionally do NOT add audio input here.
        // HotwordManager owns the mic when AssistCaptureView is open.
        // Call setSessionAudioEnabled(true) explicitly only when recording video.
        configureVideoOnly()
    }

    private func configureVideoOnly() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard
                let videoDevice = AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video, position: self.currentPosition),
                let vInput = try? AVCaptureDeviceInput(device: videoDevice),
                self.session.canAddInput(vInput)
            else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(vInput)
            self.videoInput = vInput

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
            DispatchQueue.main.async { self.isSessionReady = true }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isSessionReady = false }
        }
    }

    func flip() {
        sessionQueue.async {
            self.currentPosition = (self.currentPosition == .back) ? .front : .back
            self.session.beginConfiguration()
            if let currentVideo = self.videoInput {
                self.session.removeInput(currentVideo)
            }
            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video, position: self.currentPosition),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            self.videoInput = input
            self.session.commitConfiguration()
        }
    }

    /// Toggle the microphone input on the capture session.
    /// Disable before starting HotwordManager (lets it own the mic).
    /// Enable only when you need audio for video recording.
    func setSessionAudioEnabled(_ enabled: Bool) {
        sessionQueue.async {
            self.session.beginConfiguration()
            if enabled {
                guard self.audioInput == nil else {
                    self.session.commitConfiguration()
                    return
                }
                if let mic = AVCaptureDevice.default(for: .audio),
                   let aInput = try? AVCaptureDeviceInput(device: mic),
                   self.session.canAddInput(aInput) {
                    self.session.addInput(aInput)
                    self.audioInput = aInput
                }
            } else {
                if let aInput = self.audioInput {
                    self.session.removeInput(aInput)
                    self.audioInput = nil
                }
            }
            self.session.commitConfiguration()
        }
    }

    func captureJPEG() async -> Data? {
        guard session.isRunning else {
            print("CameraController: captureJPEG — session not running")
            return nil
        }
        return await withCheckedContinuation { (cont: CheckedContinuation<Data?, Never>) in
            sessionQueue.async {
                let settings = AVCapturePhotoSettings()
                let delegate = PhotoDelegate { [weak self] data in
                    cont.resume(returning: data)
                    self?.inFlightPhotoDelegate = nil
                }
                self.inFlightPhotoDelegate = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
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
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            sessionQueue.async {
                if !self.movieOutput.isRecording {
                    DispatchQueue.main.async { self.isRecording = false }
                    cont.resume(returning: nil)
                    return
                }
                self.recordingBox.value = cont
                self.movieOutput.stopRecording()
            }
        }
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { self.isRecording = false }
        if error != nil {
            recordingBox.value?.resume(returning: nil)
        } else {
            recordingBox.value?.resume(returning: outputFileURL)
        }
        recordingBox.value = nil
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let onData: (Data?) -> Void
    init(onData: @escaping (Data?) -> Void) { self.onData = onData }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        onData(error != nil ? nil : photo.fileDataRepresentation())
    }
}
//testing adding to github
