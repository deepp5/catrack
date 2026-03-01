import Foundation
import AVFoundation
import UIKit
import Combine

// Fix: wrap the continuation in a class so nonisolated delegate can access it
// without triggering main-actor isolation warnings
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

    // Fix: store continuation in a Sendable box so nonisolated delegate can safely access it
    private let recordingBox = ContinuationBox()

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
        guard session.isRunning else {
            print("CameraController: captureJPEG called but session is not running")
            return nil
        }

        return await withCheckedContinuation { (cont: CheckedContinuation<Data?, Never>) in
            sessionQueue.async {
                let settings = AVCapturePhotoSettings()

                if #available(iOS 16.0, *) {
                    // Use device's actual supported dimensions — never hardcode
                    let supported = self.videoInput?.device.activeFormat.supportedMaxPhotoDimensions ?? []
                    if let best = supported.last {
                        settings.maxPhotoDimensions = best
                    }
                }

                let delegate = PhotoDelegate { data in
                    cont.resume(returning: data)
                }
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
                // Fix: objc_setAssociatedObject requires UnsafeRawPointer key.
                // Allocate a unique pointer per capture to keep each delegate alive until callback fires.
                let key = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                objc_setAssociatedObject(self, key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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

// Fix: nonisolated delegate accesses recordingBox (Sendable) not a main-actor property
extension CameraController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
        }

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

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        onData(error != nil ? nil : photo.fileDataRepresentation())
    }
}
