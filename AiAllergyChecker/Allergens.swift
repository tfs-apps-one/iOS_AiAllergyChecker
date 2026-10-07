//
//  Allergens.swift
//  AiAllergyChecker
//
//  アレルゲン定義とキーワード照合ロジック（Android 版 AllergyAnalyzer.java の移植）。
//
//  [基本 9 品目]  index 0–8   … 常に検出
//  [拡張 20 品目] index 9–28  … 特定原材料に準ずるもの（動画視聴で 24 時間解放）
//

import Foundation

nonisolated enum AllergenCategory: Int, CaseIterable, Sendable {
    case basic = 0, meat, seafood, nuts, fruit, other

    /// ダッシュボードの凡例ラベル
    var label: String {
        switch self {
        case .basic:   return "基本"
        case .meat:    return "肉"
        case .seafood: return "魚介"
        case .nuts:    return "豆・種実"
        case .fruit:   return "果物・野菜"
        case .other:   return "他"
        }
    }
}

nonisolated struct Allergen: Sendable, Identifiable {
    let id: Int
    let nameJa: String
    let shortJa: String
    let nameEn: String
    let category: AllergenCategory
    /// 検出キーワード
    let keywords: [String]
    /// 文脈除外語（例：「鶏もも肉」の「もも」は桃ではない）
    let excludes: [String]
}

nonisolated enum Allergens {

    /// 常に検出する品目数（特定原材料 8 + カシューナッツ）
    static let basicCount = 9

    static let all: [Allergen] = {
        typealias Row = (String, String, String, AllergenCategory, [String], [String])
        let rows: [Row] = [
            // ── 基本 9 品目（見落とし防止のため除外語なし）──
            ("卵", "卵", "Egg", .basic, ["卵", "たまご", "玉子"], []),
            ("乳", "乳", "Milk", .basic, ["乳", "ミルク", "牛乳", "乳成分"], []),
            ("小麦", "小麦", "Wheat", .basic, ["小麦", "こむぎ"], []),
            ("えび", "えび", "Shrimp", .basic, ["えび", "エビ", "海老"], []),
            ("かに", "かに", "Crab", .basic, ["かに", "カニ", "蟹"], []),
            ("そば", "そば", "Buckwheat", .basic, ["そば", "ソバ", "蕎麦"], []),
            ("落花生", "落花生", "Peanut", .basic, ["落花生", "ピーナッツ"], []),
            ("くるみ", "くるみ", "Walnut", .basic, ["くるみ", "クルミ", "胡桃"], []),
            ("カシューナッツ", "カシュー", "Cashew", .basic, ["カシューナッツ", "かしゅーなっつ"], []),

            // ── 拡張 20 品目（特定原材料に準ずるもの）──
            // 肉類
            ("牛肉", "牛肉", "Beef", .meat, ["牛肉", "ビーフ", "牛脂", "牛エキス", "牛骨"], []),
            ("鶏肉", "鶏肉", "Chicken", .meat,
             ["鶏肉", "とり肉", "チキン", "鶏エキス", "鶏ガラ", "鶏脂", "鶏がら",
              "鶏もも", "鶏むね", "鶏ささみ", "鶏皮", "鶏ミンチ"], []),
            ("豚肉", "豚肉", "Pork", .meat, ["豚", "ポーク", "ぶた肉"], []),
            // 魚介類
            ("あわび", "あわび", "Abalone", .seafood, ["あわび", "アワビ", "鮑"], []),
            ("いか", "いか", "Squid", .seafood, ["いか", "イカ", "烏賊"],
             ["すいか", "スイカ", "西瓜", "いかなご", "イカナゴ"]),
            ("いくら", "いくら", "Salmon roe", .seafood, ["いくら", "イクラ"], []),
            ("さけ", "さけ", "Salmon", .seafood, ["さけ", "サケ", "鮭", "サーモン"], ["さける", "サケル"]),
            ("さば", "さば", "Mackerel", .seafood, ["さば", "サバ", "鯖"], ["サバイバル"]),
            // 豆・種実類
            ("大豆", "大豆", "Soybean", .nuts, ["大豆", "だいず", "ダイズ", "豆乳"], []),
            ("ごま", "ごま", "Sesame", .nuts, ["ごま", "ゴマ", "胡麻"], ["ごまかし"]),
            ("アーモンド", "アーモンド", "Almond", .nuts, ["アーモンド"], []),
            ("マカダミアナッツ", "マカダミア", "Macadamia", .nuts, ["マカダミア", "マカデミア"], []),
            // 果物・野菜
            ("オレンジ", "オレンジ", "Orange", .fruit, ["オレンジ"], []),
            ("キウイフルーツ", "キウイ", "Kiwi", .fruit, ["キウイ", "キウィ"], []),
            ("バナナ", "バナナ", "Banana", .fruit, ["バナナ"], []),
            ("もも", "もも", "Peach", .fruit, ["もも", "モモ", "桃", "ピーチ"],
             ["もも肉", "モモ肉", "すもも", "スモモ", "鶏もも", "鶏モモ"]),
            ("りんご", "りんご", "Apple", .fruit, ["りんご", "リンゴ", "林檎", "アップル"], []),
            ("やまいも", "やまいも", "Yam", .fruit,
             ["やまいも", "ヤマイモ", "山芋", "山いも", "長芋", "長いも", "ながいも", "大和芋", "とろろ"], []),
            // その他
            ("ピスタチオ", "ピスタチオ", "Pistachio", .other, ["ピスタチオ"], []),
            ("ゼラチン", "ゼラチン", "Gelatin", .other, ["ゼラチン"], []),
        ]
        return rows.enumerated().map { i, r in
            Allergen(id: i, nameJa: r.0, shortJa: r.1, nameEn: r.2, category: r.3,
                     keywords: r.4, excludes: r.5)
        }
    }()

    /// 全品目数（基本 9 + 拡張 20 = 29）
    static var totalCount: Int { all.count }
}

// MARK: - Keyword matching

/// Android 版の containsAllergenKeyword / isSurroundedByKatakana / isPartOfExcludedWord を
/// UTF-16 単位でそのまま移植したもの（Java の String.indexOf と同じ挙動になるようにしている）。
nonisolated enum AllergenMatcher {

    /// `text` の中で、`keyword` が「本物のアレルゲン表記」として現れる最初の位置（UTF-16 オフセット）。
    ///
    /// 除外ルール：
    ///  - 前後が両方カタカナ（例：OCR 誤読「パスタソバス」の「ソバ」）
    ///  - `excludes` の語の一部（例：「鶏もも肉」の「もも」）
    static func firstMatch(in text: [UInt16], keyword: [UInt16], excludes: [[UInt16]]) -> Int? {
        guard !keyword.isEmpty, text.count >= keyword.count else { return nil }
        var from = 0
        while let idx = indexOf(keyword, in: text, from: from) {
            if !isSurroundedByKatakana(text, start: idx, length: keyword.count)
                && !isPartOfExcludedWord(text, at: idx, keyword: keyword, excludes: excludes) {
                return idx
            }
            from = idx + keyword.count
        }
        return nil
    }

    /// String 版（テスト・簡易利用向け）
    static func contains(_ text: String, keyword: String, excludes: [String] = []) -> Bool {
        firstMatch(in: Array(text.utf16),
                   keyword: Array(keyword.utf16),
                   excludes: excludes.map { Array($0.utf16) }) != nil
    }

    // MARK: Helpers

    static func indexOf(_ needle: [UInt16], in hay: [UInt16], from: Int) -> Int? {
        let n = needle.count
        guard n > 0, from >= 0, hay.count - n >= from else { return nil }
        var i = from
        while i <= hay.count - n {
            if hay[i] == needle[0] {
                var j = 1
                while j < n && hay[i + j] == needle[j] { j += 1 }
                if j == n { return i }
            }
            i += 1
        }
        return nil
    }

    private static func startsWith(_ hay: [UInt16], _ prefix: [UInt16], at start: Int) -> Bool {
        guard start >= 0, start + prefix.count <= hay.count else { return false }
        for k in 0..<prefix.count where hay[start + k] != prefix[k] { return false }
        return true
    }

    private static func isPartOfExcludedWord(_ text: [UInt16], at idx: Int,
                                             keyword: [UInt16], excludes: [[UInt16]]) -> Bool {
        for ex in excludes {
            var k = indexOf(keyword, in: ex, from: 0)
            while let kk = k {
                let start = idx - kk
                if start >= 0 && startsWith(text, ex, at: start) { return true }
                k = indexOf(keyword, in: ex, from: kk + 1)
            }
        }
        return false
    }

    private static func isSurroundedByKatakana(_ text: [UInt16], start: Int, length: Int) -> Bool {
        let prev = start > 0 && isKatakana(text[start - 1])
        let end = start + length
        let next = end < text.count && isKatakana(text[end])
        return prev && next
    }

    /// 全角カタカナ U+30A1（ァ）–U+30F6（ヶ）と U+30FC（ー）。
    /// U+30FB（・）は区切り文字なので意図的に除外。
    private static func isKatakana(_ c: UInt16) -> Bool {
        (c >= 0x30A1 && c <= 0x30F6) || c == 0x30FC
    }
}
