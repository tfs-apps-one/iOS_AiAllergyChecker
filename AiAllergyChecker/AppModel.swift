//
//  AppModel.swift
//  AiAllergyChecker
//
//  画面の状態とロジック（Android 版 MainActivity のロジック部分に相当）。
//
//  ・AR 枠の安定化フィルタ：同じ位置で STABILITY_REQUIRED フレーム連続検出されたら確定表示、
//    確定後は ALLERGEN_TIMEOUT 秒保持（注意書きの一瞬の誤検出を除外）
//  ・ダッシュボード：検出後 ALLERGEN_TIMEOUT 秒点灯
//  ・拡張モード：リワード動画視聴で 20 品目追加（計 29 品目）を 24 時間解放
//

import SwiftUI
import AVFoundation
import Observation

@Observable
final class AppModel {

    // MARK: Constants

    static let allergenTimeout: TimeInterval = 1.5
    static let stabilityRequired = 2
    static let samePosRatio: CGFloat = 0.08
    static let expandDuration: TimeInterval = 24 * 60 * 60
    static let rateMinLaunches = 3

    private enum Key {
        static let termsAgreed = "terms_agreed"
        static let launchCount = "launch_count"
        static let rateDone = "rate_dialog_done"
        static let expandUntil = "expand_until_ms"
        static let expandEnabled = "expand_enabled"
        static let detectedOnly = "display_detected_only"
    }

    enum CameraState: Equatable { case idle, running, denied, unavailable }

    // MARK: UI state

    var termsAgreed = false
    var cameraState: CameraState = .idle

    /// true = 29 品目 / false = 9 品目
    private(set) var expanded = false
    /// true = 検出したアレルゲンだけを大きく表示
    private(set) var detectedOnly = false

    /// 各品目の点灯状態（index 0–28）
    private(set) var active: [Bool] = Array(repeating: false, count: Allergens.totalCount)
    private(set) var numActive = 0

    /// オーバーレイに表示する確定済みの枠
    private(set) var displayBoxes: [AllergenBox] = []
    private(set) var imageSize: CGSize = .zero

    /// 解放期限までの残り（秒）。0 = 未解放
    private(set) var remainingUnlock: TimeInterval = 0

    var showSettings = false
    var showRewardConfirm = false
    var showRewardLoading = false
    var toast: ToastMessage?

    var visibleCount: Int { expanded ? Allergens.totalCount : Allergens.basicCount }

    // MARK: Internal state

    let camera = CameraManager()
    let rewarded = RewardedAdController()
    private let defaults = UserDefaults.standard
    @ObservationIgnored private var ticker: Timer?

    @ObservationIgnored private var lastDetected = [TimeInterval](repeating: 0, count: Allergens.totalCount)
    @ObservationIgnored private var lastRawBox = [AllergenBox?](repeating: nil, count: Allergens.totalCount)
    @ObservationIgnored private var boxStability = [Int](repeating: 0, count: Allergens.totalCount)
    @ObservationIgnored private var confirmedBox = [AllergenBox?](repeating: nil, count: Allergens.totalCount)
    @ObservationIgnored private var boxConfirmedAt = [TimeInterval](repeating: 0, count: Allergens.totalCount)

    // MARK: Init

    init() {
        termsAgreed = defaults.bool(forKey: Key.termsAgreed)
        detectedOnly = defaults.bool(forKey: Key.detectedOnly)

        let launches = defaults.integer(forKey: Key.launchCount) + 1
        defaults.set(launches, forKey: Key.launchCount)

        camera.onResult = { [weak self] result in
            Task { @MainActor [weak self] in self?.handle(result) }
        }
        camera.onError = { [weak self] _ in
            Task { @MainActor [weak self] in self?.cameraState = .unavailable }
        }
        rewarded.onReward = { [weak self] in self?.saveUnlock() }
        rewarded.onDismiss = { [weak self] earned in self?.rewardDismissed(earned: earned) }
        rewarded.onLoadResult = { [weak self] ok in self?.rewardLoadFinished(ok: ok) }
        rewarded.onPresentFailed = { [weak self] in
            self?.showToast("動画を読み込めませんでした。通信環境を確認して、しばらくしてからお試しください。")
        }

        applyMode(shouldBeExpanded, force: true)
        startTicker()
    }

    // MARK: Lifecycle

    func agreeToTerms() {
        defaults.set(true, forKey: Key.termsAgreed)
        termsAgreed = true
        startCameraIfPermitted()
    }

    func startCameraIfPermitted() {
        guard termsAgreed else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraState = .running
            camera.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.cameraState = .running
                        self.camera.start()
                    } else {
                        self.cameraState = .denied
                    }
                }
            }
        default:
            cameraState = .denied
        }
    }

    func onForeground() {
        startCameraIfPermitted()
        tick()
    }

    func onBackground() {
        camera.stop()
    }

    /// 評価リクエストを出すべきか（3 回以上起動・未実施）。呼んだら実施済みにする。
    func consumeRateRequest() -> Bool {
        guard termsAgreed,
              !defaults.bool(forKey: Key.rateDone),
              defaults.integer(forKey: Key.launchCount) >= Self.rateMinLaunches else { return false }
        defaults.set(true, forKey: Key.rateDone)
        return true
    }

    // MARK: Frame handling

    private func handle(_ r: FrameResult) {
        let now = Date().timeIntervalSince1970
        let count = visibleCount       // モード切替直後の古いフレームで非表示品目が光らないように
        if imageSize != r.imageSize { imageSize = r.imageSize }

        var newMap: [Int: AllergenBox] = [:]
        for b in r.boxes { newMap[b.index] = b }

        // Step 1: 安定度の更新
        for i in 0..<count {
            if let nb = newMap[i] {
                if isSamePosition(nb, lastRawBox[i], imageHeight: r.imageSize.height) {
                    boxStability[i] = min(boxStability[i] + 1, Self.stabilityRequired + 1)
                } else {
                    boxStability[i] = 1
                }
                lastRawBox[i] = nb
                if boxStability[i] >= Self.stabilityRequired {
                    confirmedBox[i] = nb
                    boxConfirmedAt[i] = now
                }
            } else {
                boxStability[i] = 0
                lastRawBox[i] = nil
            }
        }

        // Step 3: ダッシュボードのタイムスタンプ
        for idx in r.detected where idx >= 0 && idx < count {
            lastDetected[idx] = now
        }

        refresh(now: now)
    }

    private func isSamePosition(_ a: AllergenBox?, _ b: AllergenBox?, imageHeight: CGFloat) -> Bool {
        guard let a, let b, imageHeight > 0 else { return false }
        let threshold = max(30 / imageHeight, Self.samePosRatio)   // 正規化座標
        return abs(a.rect.midY - b.rect.midY) <= threshold
    }

    /// 点灯状態・オーバーレイ枠を現在時刻で更新（フレーム毎 + タイマー）
    private func refresh(now: TimeInterval = Date().timeIntervalSince1970) {
        let count = visibleCount
        var newActive = [Bool](repeating: false, count: Allergens.totalCount)
        var n = 0
        for i in 0..<count where now - lastDetected[i] < Self.allergenTimeout {
            newActive[i] = true
            n += 1
        }
        if newActive != active { active = newActive }
        if n != numActive { numActive = n }

        var boxes: [AllergenBox] = []
        for i in 0..<count {
            if let b = confirmedBox[i], now - boxConfirmedAt[i] < Self.allergenTimeout {
                boxes.append(b)
            }
        }
        if boxes != displayBoxes { displayBoxes = boxes }
    }

    // MARK: Ticker

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        refresh()

        let remain = remainingUnlockSeconds()
        if Int(remain) != Int(remainingUnlock) || (remain == 0) != (remainingUnlock == 0) {
            remainingUnlock = remain
        }

        if expanded && remain <= 0 {
            defaults.set(false, forKey: Key.expandEnabled)
            applyMode(false)
            showToast("拡張モードの有効期限が切れたため、9品目に戻しました")
        } else if !expanded && shouldBeExpanded {
            applyMode(true)
        }
    }

    // MARK: Expanded mode

    private func remainingUnlockSeconds() -> TimeInterval {
        let untilMs = defaults.double(forKey: Key.expandUntil)
        let remain = untilMs / 1000 - Date().timeIntervalSince1970
        // 端末時刻を巻き戻した不正延長を防ぐ（残りが 24h を超えたら無効）
        if remain <= 0 || remain > Self.expandDuration { return 0 }
        return remain
    }

    var isExpandUnlocked: Bool { remainingUnlockSeconds() > 0 }

    private var shouldBeExpanded: Bool {
        isExpandUnlocked && defaults.bool(forKey: Key.expandEnabled)
    }

    /// 9 品目 / 29 品目を切り替える
    func applyMode(_ newExpanded: Bool, force: Bool = false) {
        remainingUnlock = remainingUnlockSeconds()
        guard force || newExpanded != expanded else { return }
        expanded = newExpanded

        // 拡張品目の検出状態をリセット（OFF にした瞬間に赤枠が残らないように）
        for i in Allergens.basicCount..<Allergens.totalCount {
            lastDetected[i] = 0
            boxConfirmedAt[i] = 0
            confirmedBox[i] = nil
            lastRawBox[i] = nil
            boxStability[i] = 0
        }
        camera.analyzer.activeCount = visibleCount
        refresh()
    }

    /// 設定のスイッチ操作
    func setExpandSwitch(_ on: Bool) {
        if on {
            if isExpandUnlocked {
                defaults.set(true, forKey: Key.expandEnabled)
                applyMode(true)
            } else {
                showRewardConfirm = true
            }
        } else {
            defaults.set(false, forKey: Key.expandEnabled)
            applyMode(false)
        }
    }

    func setDetectedOnly(_ on: Bool) {
        guard on != detectedOnly else { return }
        detectedOnly = on
        defaults.set(on, forKey: Key.detectedOnly)
    }

    // MARK: Rewarded ad

    func settingsOpened() {
        tick()
        // 【初回リリースでは広告無効】
        // if !isExpandUnlocked { rewarded.load() }   // 先読み
    }

    func watchRewardedAd() {
        // 【初回リリースでは広告無効】
        // if rewarded.isReady {
        //     rewarded.present()
        // } else {
        //     showRewardLoading = true
        //     rewarded.load()
        // }
    }

    func cancelRewardLoading() {
        showRewardLoading = false
    }

    private func rewardLoadFinished(ok: Bool) {
        guard showRewardLoading else { return }
        showRewardLoading = false
        if ok {
            rewarded.present()
        } else {
            showToast("動画を読み込めませんでした。通信環境を確認して、しばらくしてからお試しください。")
        }
    }

    /// 視聴完了：即座に保存（広告表示中にアプリが終了しても特典を失わない）
    private func saveUnlock() {
        let until = (Date().timeIntervalSince1970 + Self.expandDuration) * 1000
        defaults.set(until, forKey: Key.expandUntil)
        defaults.set(true, forKey: Key.expandEnabled)
    }

    private func rewardDismissed(earned: Bool) {
        if earned {
            applyMode(true)
            showToast("拡張モードを24時間解放しました（29品目）")
        } else {
            showToast("動画を最後まで視聴すると解放されます。")
        }
    }

    // MARK: Toast

    func showToast(_ text: String) {
        let msg = ToastMessage(text: text)
        toast = msg
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.toast?.id == msg.id { self?.toast = nil }
        }
    }
}

struct ToastMessage: Equatable, Identifiable {
    let id = UUID()
    let text: String
}

/// HH:MM:SS
func formatHMS(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}
