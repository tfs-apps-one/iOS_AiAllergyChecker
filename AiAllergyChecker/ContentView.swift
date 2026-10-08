//
//  ContentView.swift
//  AiAllergyChecker
//
//  画面構成（Android 版 activity_main.xml 相当）
//   ・上：カメラ（プレビュー + AR オーバーレイ + 注意書き）
//   ・中：ALLERGEN MONITOR
//   ・下：AdMob バナー
//  29 品目の一覧表示のときだけダッシュボードを広げる（カメラ 2:1 → 1.55:1）。
//

import SwiftUI
import StoreKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        @Bindable var model = model

        GeometryReader { outer in
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let cameraWeight: CGFloat = (model.expanded && !model.detectedOnly) ? 1.55 : 2
                    let cameraH = geo.size.height * cameraWeight / (cameraWeight + 1)
                    VStack(spacing: 0) {
                        cameraArea
                            .frame(height: cameraH)
                            .clipped()
                        DashboardView()
                            .frame(maxHeight: .infinity)
                    }
                    .animation(.easeInOut(duration: 0.25), value: cameraWeight)
                }

                // 【初回リリースでは広告無効】ダウンロード数が増えてから有効化する
                // if model.termsAgreed {
                //     BannerAdView(width: outer.size.width)
                //         .background(Color.black)
                // }
            }
        }
        .background(Color.black)
        .overlay {
            if !model.termsAgreed {
                TermsView()
            }
        }
        .toast(model.toast)
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panelTop)
                .presentationCornerRadius(20)
        }
        .onAppear {
            model.startCameraIfPermitted()
            maybeRequestReview()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.onForeground()
            case .background: model.onBackground()
            default: break
            }
        }
        .onChange(of: model.termsAgreed) { _, agreed in
            if agreed { maybeRequestReview() }
        }
    }

    // MARK: Camera

    private var cameraArea: some View {
        ZStack(alignment: .top) {
            switch model.cameraState {
            case .running, .idle:
                CameraPreviewView(session: model.camera.session)
                OverlayView(boxes: model.displayBoxes, imageSize: model.imageSize)
            case .denied:
                cameraMessage(
                    "カメラのアクセス許可が必要です。\n設定アプリから許可してください。",
                    buttonTitle: "設定を開く"
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            case .unavailable:
                cameraMessage("カメラの起動に失敗しました", buttonTitle: nil, action: nil)
            }

            // 常時表示の注意書き
            Text("【注意】本アプリは補助ツールです。アレルギー物質は必ずご自身で目視確認してください。利用によるいかなる被害も開発者は一切責任を負いません。")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.73))
        }
        .background(Color.black)
    }

    private func cameraMessage(_ text: String, buttonTitle: String?, action: (() -> Void)?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textMuted)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textMain)
                .multilineTextAlignment(.center)
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.red, in: Capsule())
            }
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Review

    /// 3 回以上起動したユーザーに 1 度だけ、iOS 標準の評価ダイアログを依頼する
    /// （表示するかどうかは iOS が判断。App Store の規約上、独自の評価ダイアログは使わない）
    private func maybeRequestReview() {
        guard model.consumeRateRequest() else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))   // カメラ起動と重ならないよう少し遅らせる
            requestReview()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .preferredColorScheme(.dark)
}
