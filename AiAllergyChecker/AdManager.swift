//
//  AdManager.swift
//  AiAllergyChecker
//
//  Google AdMob（アンカー型アダプティブバナー + リワード動画）。
//  Swift Package「GoogleMobileAds」(v12) が追加されていない場合は広告なしでビルドできるようにしている。
//

import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdConfig {
    // ⚠️ 現在は Google 公式の iOS テスト用 ID です。
    //    AdMob 管理画面で iOS アプリを追加し、本番の ID に差し替えてからリリースしてください。
    //    （アプリ ID は Info.plist の GADApplicationIdentifier も同様に差し替え）
    static let bannerUnitID   = "ca-app-pub-3940256099942544/2435281174"
    static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    static func start() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start { _ in }
        #endif
    }
}

/// 最前面のビューコントローラ（設定シート表示中はシート）
@MainActor
func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        ?? scene?.windows.first?.rootViewController
    while let presented = vc?.presentedViewController { vc = presented }
    return vc
}

// MARK: - Banner

struct BannerAdView: View {
    /// 表示幅（親の GeometryReader から渡す）
    let width: CGFloat

    var body: some View {
        #if canImport(GoogleMobileAds)
        if width > 0 {
            BannerRepresentable(width: width)
                .frame(width: width,
                       height: currentOrientationAnchoredAdaptiveBanner(width: width).size.height)
        }
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct BannerRepresentable: UIViewRepresentable {
    let width: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: max(width, 320)))
        banner.adUnitID = AdConfig.bannerUnitID
        banner.rootViewController = topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        guard width > 0 else { return }
        let size = currentOrientationAnchoredAdaptiveBanner(width: width)
        if uiView.adSize.size.width != size.size.width {
            uiView.adSize = size
        }
    }
}
#endif

// MARK: - Rewarded

final class RewardedAdController: NSObject {

    /// 報酬獲得（動画を最後まで視聴）
    var onReward: (() -> Void)?
    /// 広告を閉じた（earned = 報酬を獲得したか）
    var onDismiss: ((Bool) -> Void)?
    /// 読み込み完了（成功/失敗）
    var onLoadResult: ((Bool) -> Void)?
    /// 表示に失敗
    var onPresentFailed: (() -> Void)?

    private var loading = false
    private var earned = false

    #if canImport(GoogleMobileAds)
    private var ad: RewardedAd?
    var isReady: Bool { ad != nil }
    #else
    var isReady: Bool { false }
    #endif

    /// 読み込み（読み込み済み・読み込み中なら何もしない）
    func load() {
        #if canImport(GoogleMobileAds)
        guard ad == nil, !loading else { return }
        loading = true
        RewardedAd.load(with: AdConfig.rewardedUnitID, request: Request()) { [weak self] ad, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.loading = false
                if let ad {
                    ad.fullScreenContentDelegate = self
                    self.ad = ad
                    self.onLoadResult?(true)
                } else {
                    print("Rewarded ad failed to load: \(error?.localizedDescription ?? "-")")
                    self.ad = nil
                    self.onLoadResult?(false)
                }
            }
        }
        #else
        onLoadResult?(false)
        #endif
    }

    func present() {
        #if canImport(GoogleMobileAds)
        guard let ad else { return }
        self.ad = nil      // 1 回しか表示できないので手放す
        earned = false
        ad.present(from: topViewController()) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.earned = true
                self.onReward?()
            }
        }
        #endif
    }
}

#if canImport(GoogleMobileAds)
extension RewardedAdController: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        MainActor.assumeIsolated { onDismiss?(earned) }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Rewarded ad failed to show: \(error.localizedDescription)")
        MainActor.assumeIsolated { onPresentFailed?() }
    }
}
#endif
