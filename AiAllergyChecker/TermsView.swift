//
//  TermsView.swift
//  AiAllergyChecker
//
//  初回起動時の免責事項。同意するまでカメラは起動しない。
//  （iOS ではアプリを自分で終了できないため、「同意しない」は案内を表示してこの画面に留まる）
//

import SwiftUI

struct TermsView: View {
    @Environment(AppModel.self) private var model
    @State private var showDeclined = false

    private let terms = """
    1. 本アプリは、食品パッケージの原材料表記をカメラで認識し、アレルゲン候補をハイライトする「確認補助ツール」です。カメラの撮影環境や光の反射、フォントの種類等により、アレルギー物質を正しく検出できない（誤認識・見落とし）場合があります。

    2. アレルギー物質の有無に関する最終的な判断は、必ずユーザーご自身で実際の原材料表記を目視確認してください。

    3. 本アプリが提供する情報の正確性、完全性について開発者は一切の保証をいたしません。本アプリの利用によって生じた健康上の被害、損害、トラブル等につきまして、開発者は直接的・間接的を問わず一切の責任を負いかねますので予めご了承ください。
    """

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("免責事項（必ずお読みください）")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textMain)
                    .padding(.bottom, 12)

                ScrollView {
                    Text(terms)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textOff)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button {
                        showDeclined = true
                    } label: {
                        Text("同意しない")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.buttonBg, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Button {
                        model.agreeToTerms()
                    } label: {
                        Text("同意する")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.red, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.top, 16)
            }
            .padding(20)
            .frame(maxHeight: 560)
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardStroke, lineWidth: 1))
            .padding(20)
        }
        .alert("ご利用いただけません", isPresented: $showDeclined) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("免責事項に同意いただけない場合、本アプリはご利用いただけません。")
        }
    }
}
