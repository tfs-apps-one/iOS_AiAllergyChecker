//
//  SettingsView.swift
//  AiAllergyChecker
//
//  設定シート（Android 版 dialog_settings.xml / showSettingsSheet 相当）。
//   ・表示モード（全品目 / 検出のみ）
//   ・拡張モード（リワード動画で 20 品目を 24 時間解放）
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.panelTop.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SETTINGS")
                        .font(.system(size: 11, weight: .bold).width(.condensed))
                        .tracking(1.3)
                        .foregroundStyle(Theme.textMuted)
                        .padding(.top, 14)
                    Text("設定")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textMain)

                    displayModeCard.padding(.top, 16)
                    expandCard.padding(.top, 16)

                    Text("※ 解放中はスイッチでいつでも 9品目 ⇄ 29品目 を切り替えられます。24時間が経過すると自動的に9品目に戻ります。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSubOff)
                        .lineSpacing(2)
                        .padding(.top, 12)

                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textMain)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.buttonBg, in: RoundedRectangle(cornerRadius: 24))
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            if model.showRewardLoading {
                rewardLoadingOverlay
            }
        }
        .toast(model.toast)
        .alert("20品目を24時間解放", isPresented: Binding(
            get: { model.showRewardConfirm },
            set: { model.showRewardConfirm = $0 })
        ) {
            Button("キャンセル", role: .cancel) {}
            Button("動画を見る") { model.watchRewardedAd() }
        } message: {
            Text("短い動画広告を最後まで視聴すると、拡張モード（29品目検出）が24時間使えるようになります。")
        }
        .onAppear { model.settingsOpened() }
    }

    // MARK: 表示モード

    private var displayModeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("表示モード")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textMain)
            Text("「検出のみ」にすると、見つかったアレルゲンだけを大きな文字で表示します。小さな文字が読みづらいときにおすすめです。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .lineSpacing(2)
                .padding(.top, 4)

            HStack(spacing: 0) {
                toggleButton("全品目表示", selected: !model.detectedOnly) { model.setDetectedOnly(false) }
                toggleButton("検出のみ表示", selected: model.detectedOnly) { model.setDetectedOnly(true) }
            }
            .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card)
    }

    private func toggleButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? .white : Theme.textMuted)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(selected ? Theme.red.opacity(0.25) : .clear)
                .overlay(Rectangle().stroke(selected ? Theme.red : Theme.cardStroke, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 拡張モード

    private var expandCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("拡張モード")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.textMain)
                        Text("+20")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                LinearGradient(colors: [Color(hex: 0xFF3B30), Color(hex: 0xFF8A00)],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 8))
                    }
                    Text("特定原材料に準ずるもの20品目を追加して、計29品目を検出します。動画を1本見ると24時間使えます。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .lineSpacing(2)
                }
                Toggle("", isOn: Binding(
                    get: { model.expanded },
                    set: { model.setExpandSwitch($0) })
                )
                .labelsHidden()
                .tint(Theme.red)
            }

            Text(statusText)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(model.remainingUnlock > 0 ? Theme.accentAmber : Theme.textMuted)
                .padding(.top, 12)

            Rectangle()
                .fill(Theme.cardStroke)
                .frame(height: 1)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Text("追加される20品目")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textOff)

            VStack(alignment: .leading, spacing: 4) {
                itemRow("肉類", "牛肉・鶏肉・豚肉")
                itemRow("魚介類", "あわび・いか・いくら・さけ・さば")
                itemRow("豆・種実類", "大豆・ごま・アーモンド・マカダミアナッツ")
                itemRow("果物・野菜", "オレンジ・キウイフルーツ・バナナ・もも・りんご・やまいも")
                itemRow("その他", "ピスタチオ・ゼラチン")
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.textMuted)
            .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card)
    }

    private func itemRow(_ head: String, _ items: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(head).frame(width: 72, alignment: .leading)
            Text(items).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusText: String {
        model.remainingUnlock > 0
            ? "UNLOCKED ─ 残り \(formatHMS(model.remainingUnlock))"
            : "LOCKED ─ 動画視聴で24時間解放"
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Theme.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardStroke, lineWidth: 1))
    }

    // MARK: 読み込み中

    private var rewardLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ProgressView().tint(.white)
                    Text("動画を読み込み中…")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textMain)
                }
                Button("キャンセル") { model.cancelRewardLoading() }
                    .foregroundStyle(Theme.accentRed)
            }
            .padding(24)
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardStroke, lineWidth: 1))
        }
    }
}
