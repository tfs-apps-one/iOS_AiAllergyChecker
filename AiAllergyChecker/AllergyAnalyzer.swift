//
//  AllergyAnalyzer.swift
//  AiAllergyChecker
//
//  カメラフレームを Apple Vision（日本語テキスト認識）で解析し、
//  有効な品目（9 または 29）のキーワードを探す。
//  Android 版の ML Kit ベース AllergyAnalyzer.java に相当。
//

import Foundation
import CoreGraphics
import CoreVideo
import Vision

/// 検出されたアレルゲンの枠。
nonisolated struct AllergenBox: Sendable, Equatable {
    /// 画像に対する正規化座標（0–1、左上原点）
    let rect: CGRect
    /// OCR の信頼度 0–1
    let confidence: Float
    /// Allergens.all のインデックス
    let index: Int
}

/// 1 フレーム分の解析結果。
nonisolated struct FrameResult: Sendable {
    let boxes: [AllergenBox]
    let detected: Set<Int>
    /// 解析した画像のサイズ（px、縦向き）
    let imageSize: CGSize
}

nonisolated final class AllergyAnalyzer: @unchecked Sendable {

    /// この値以上の信頼度は赤、それ未満は黄で表示。
    /// Vision の日本語認識は 0.3 / 0.5 / 1.0 前後の値を返すことが多いため 0.5 を境にしている。
    static let highConfidenceThreshold: Float = 0.5

    private let lock = NSLock()
    private var _activeCount = Allergens.basicCount

    /// 検出対象の品目数（9 または 29）。どのスレッドからでも変更可。次のフレームから反映。
    var activeCount: Int {
        get { lock.withLock { _activeCount } }
        set { lock.withLock { _activeCount = max(1, min(newValue, Allergens.totalCount)) } }
    }

    // キーワードは UTF-16 に変換して保持（毎フレームの変換を避ける）
    private let keywordUnits: [[[UInt16]]]
    private let excludeUnits: [[[UInt16]]]

    init() {
        keywordUnits = Allergens.all.map { $0.keywords.map { Array($0.utf16) } }
        excludeUnits = Allergens.all.map { $0.excludes.map { Array($0.utf16) } }
    }

    /// 縦向き（.up）のピクセルバッファを同期的に解析する。カメラのキューから呼ばれる。
    func analyze(pixelBuffer: CVPixelBuffer) -> FrameResult? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate          // 日本語は .accurate のみ対応
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        let activeCount = self.activeCount

        // 品目 → 最も上にある枠
        //  原材料欄と「本製品は乳成分を含む製品と共通の設備で…」の注意書きの両方に同じ語がある場合、
        //  上側（原材料欄）を優先して強調するため、品目ごとに最上部の 1 つだけ残す。
        var best: [Int: AllergenBox] = [:]
        var detected = Set<Int>()

        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let units = Array(text.utf16)

            for i in 0..<activeCount {
                for kw in keywordUnits[i] {
                    guard let off = AllergenMatcher.firstMatch(in: units, keyword: kw,
                                                               excludes: excludeUnits[i]) else { continue }
                    detected.insert(i)

                    // キーワード部分だけの枠を取得（取れなければ行全体）
                    var bb = observation.boundingBox
                    let start = String.Index(utf16Offset: off, in: text)
                    let end = String.Index(utf16Offset: off + kw.count, in: text)
                    if start < end, let sub = try? candidate.boundingBox(for: start..<end) {
                        bb = sub.boundingBox
                    }
                    // Vision は左下原点 → 左上原点へ
                    let rect = CGRect(x: bb.minX, y: 1 - bb.maxY, width: bb.width, height: bb.height)
                    let box = AllergenBox(rect: rect, confidence: candidate.confidence, index: i)
                    if let prev = best[i], prev.rect.minY <= rect.minY {
                        // 既存の方が上にある
                    } else {
                        best[i] = box
                    }
                    break   // 1 行につき 1 品目 1 回で十分
                }
            }
        }

        return FrameResult(boxes: Array(best.values), detected: detected, imageSize: size)
    }
}
