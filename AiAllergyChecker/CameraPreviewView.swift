//
//  CameraPreviewView.swift
//  AiAllergyChecker
//
//  AVCaptureVideoPreviewLayer を SwiftUI で表示する（Android 版 PreviewView / centerCrop 相当）。
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.backgroundColor = .black
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        private var startObserver: NSObjectProtocol?

        override init(frame: CGRect) {
            super.init(frame: frame)
            // セッション開始後に接続ができるので、そのタイミングで向きを合わせ直す
            startObserver = NotificationCenter.default.addObserver(
                forName: AVCaptureSession.didStartRunningNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.setNeedsLayout() }
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            // アプリは縦固定。プレビューも縦向き（90°）に合わせる
            if let c = previewLayer.connection, c.isVideoRotationAngleSupported(90), c.videoRotationAngle != 90 {
                c.videoRotationAngle = 90
            }
        }
    }
}
