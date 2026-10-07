//
//  AiAllergyCheckerTests.swift
//  AiAllergyCheckerTests
//
//  キーワード照合ルール（Android 版と同じ挙動）の確認。
//

import Testing
import CoreGraphics
@testable import AiAllergyChecker

@MainActor
struct AllergenMatcherTests {

    @Test func definitions() {
        #expect(Allergens.totalCount == 29)
        #expect(Allergens.basicCount == 9)
        #expect(Allergens.all[8].nameJa == "カシューナッツ")
        #expect(Allergens.all[28].nameJa == "ゼラチン")
    }

    @Test func basicMatches() {
        #expect(AllergenMatcher.contains("原材料名：小麦粉、砂糖、卵", keyword: "卵"))
        #expect(AllergenMatcher.contains("（一部に乳成分・大豆を含む）", keyword: "乳成分"))
        #expect(AllergenMatcher.contains("…、ソバ粉、…", keyword: "ソバ"))
        #expect(AllergenMatcher.contains("ソバ・えび", keyword: "ソバ"))
        #expect(AllergenMatcher.contains("エビフライ", keyword: "エビ"))
    }

    /// 前後がカタカナに挟まれた語は外来語の一部とみなして除外（OCR 誤読「パスタソバス」対策）
    @Test func katakanaGuard() {
        #expect(!AllergenMatcher.contains("パスタソバス", keyword: "ソバ"))
        #expect(AllergenMatcher.contains("パスタソバス、ソバ", keyword: "ソバ"))
    }

    /// 文脈除外語
    @Test func excludes() {
        let peach = Allergens.all[24]
        #expect(!AllergenMatcher.contains("鶏もも肉", keyword: "もも", excludes: peach.excludes))
        #expect(!AllergenMatcher.contains("すもも", keyword: "もも", excludes: peach.excludes))
        #expect(AllergenMatcher.contains("もも果汁", keyword: "もも", excludes: peach.excludes))

        let squid = Allergens.all[13]
        #expect(!AllergenMatcher.contains("すいか果汁", keyword: "いか", excludes: squid.excludes))
        #expect(AllergenMatcher.contains("するめいか", keyword: "いか", excludes: squid.excludes))
    }

    @Test func utf16Offset() {
        let text = Array("原材料：小麦、卵".utf16)
        #expect(AllergenMatcher.firstMatch(in: text, keyword: Array("卵".utf16), excludes: []) == 7)
    }

    @Test func overlayTransform() {
        // 1080x1920 の画像を 390x500 のビューに aspectFill
        let r = OverlayView.transform(CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.05),
                                      imageSize: CGSize(width: 1080, height: 1920),
                                      viewSize: CGSize(width: 390, height: 500))
        #expect(r != nil)
        #expect(abs(r!.minX - 195) < 0.01)
    }
}
