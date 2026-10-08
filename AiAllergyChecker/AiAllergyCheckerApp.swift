//
//  AiAllergyCheckerApp.swift
//  AiAllergyChecker
//
//  Created by 古川貴史 on 2026/10/06.
//

import SwiftUI

@main
struct AiAllergyCheckerApp: App {
    @State private var model = AppModel()

    init() {
        // 広告 SDK の初期化（起動・カメラを遅らせないよう非同期）
        // 【初回リリースでは広告無効】ダウンロード数が増えてから有効化する
        // AdConfig.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}
