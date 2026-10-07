//
//  CameraManager.swift
//  AiAllergyChecker
//
//  AVCaptureSession の管理（Android 版の CameraX Preview + ImageAnalysis に相当）。
//  最新フレームだけを解析し、解析中に届いたフレームは捨てる（STRATEGY_KEEP_ONLY_LATEST 相当）。
//

import AVFoundation

nonisolated final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    enum SetupError: Sendable { case noCamera, configurationFailed }

    let session = AVCaptureSession()
    let analyzer = AllergyAnalyzer()

    /// 解析結果（カメラのキューから呼ばれる）
    var onResult: (@Sendable (FrameResult) -> Void)?
    /// 起動失敗（カメラのキューから呼ばれる）
    var onError: (@Sendable (SetupError) -> Void)?

    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let videoQueue = DispatchQueue(label: "camera.video", qos: .userInitiated)
    private var configured = false

    func start() {
        sessionQueue.async { [self] in
            if !configured {
                guard configure() else { return }
                configured = true
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            onError?(.noCamera)
            return false
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 原材料表示の小さな文字を読むため 1080p（16:9）
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            onError?(.configurationFailed)
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(output) else {
            onError?(.configurationFailed)
            return false
        }
        session.addOutput(output)

        // バッファを縦向きで受け取る（Vision に .up で渡せるように）
        if let conn = output.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
            conn.videoRotationAngle = 90
        }

        // 近距離のラベルにピントが合いやすいように
        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }
        return true
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // 同期的に解析（解析中のフレームは alwaysDiscardsLateVideoFrames で破棄される）
        guard let result = analyzer.analyze(pixelBuffer: pixelBuffer) else { return }
        onResult?(result)
    }
}
