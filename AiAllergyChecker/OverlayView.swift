//
//  OverlayView.swift
//  AiAllergyChecker
//
//  カメラ映像の上に重ねる AR オーバーレイ（Android 版 CustomOverlayView 相当）。
//
//  ┌─────────────────────────────────┐ ← 緑のスキャン枠
//  │ 緑枠内に原材料ラベルを映してください │
//  │   [赤枠] 信頼度（高）              │
//  │   [黄枠] 信頼度（低）              │
//  └─────────────────────────────────┘
//  ┌─────────────────────────────────┐ ← 凡例
//  │ アレルゲン検出                    │
//  │ ■ 赤：信頼度（高）  ■ 黄：信頼度（低）│
//  └─────────────────────────────────┘
//

import SwiftUI

struct OverlayView: View {
    let boxes: [AllergenBox]
    let imageSize: CGSize

    nonisolated private static let zoneWRatio: CGFloat = 0.92
    nonisolated private static let zoneHRatio: CGFloat = 0.72
    nonisolated private static let topOffsetRatio: CGFloat = 0.07

    private static let green = Color(red: 0, green: 210 / 255, blue: 90 / 255)
    private static let redFill = Color(red: 220 / 255, green: 30 / 255, blue: 30 / 255).opacity(70 / 255)
    private static let redStroke = Color(red: 220 / 255, green: 30 / 255, blue: 30 / 255).opacity(230 / 255)
    private static let yellowFill = Color(red: 230 / 255, green: 180 / 255, blue: 0).opacity(70 / 255)
    private static let yellowStroke = Color(red: 230 / 255, green: 180 / 255, blue: 0).opacity(230 / 255)
    private static let bg = Color.black.opacity(175 / 255)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let zone = Self.zoneRect(in: size)

            ZStack(alignment: .topLeading) {
                // アレルゲン枠 + 緑のスキャン枠
                Canvas { ctx, canvasSize in
                    for box in boxes {
                        guard let r = Self.transform(box.rect, imageSize: imageSize, viewSize: canvasSize) else { continue }
                        let high = box.confidence >= AllergyAnalyzer.highConfidenceThreshold
                        let path = Path(r)
                        ctx.fill(path, with: .color(high ? Self.redFill : Self.yellowFill))
                        ctx.stroke(path, with: .color(high ? Self.redStroke : Self.yellowStroke), lineWidth: 2)
                    }
                    ctx.stroke(Path(zone), with: .color(Self.green), lineWidth: 2)
                }

                // ガイド文（枠内左上）
                Text("緑枠内に原材料ラベルを映してください")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Self.green)
                    .shadow(color: .black, radius: 1, x: 0.5, y: 0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(6)
                    .background(Self.bg)
                    .frame(maxWidth: zone.width - 12, alignment: .leading)
                    .offset(x: zone.minX + 6, y: zone.minY + 6)

                // 凡例（枠の下）
                VStack(alignment: .leading, spacing: 2) {
                    Text("アレルゲン検出")
                        .font(.system(size: 13, weight: .bold))
                    HStack(spacing: 14) {
                        legendItem(fill: Self.redFill, stroke: Self.redStroke, label: "赤：信頼度（高）")
                        legendItem(fill: Self.yellowFill, stroke: Self.yellowStroke, label: "黄：信頼度（低）")
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 1, x: 0.5, y: 0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: zone.width, alignment: .leading)
                .background(Self.bg)
                .offset(x: zone.minX, y: zone.maxY + 6)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }

    private func legendItem(fill: Color, stroke: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(fill)
                .overlay(Rectangle().stroke(stroke, lineWidth: 1.5))
                .frame(width: 11, height: 11)
            Text(label).font(.system(size: 12))
        }
    }

    nonisolated static func zoneRect(in size: CGSize) -> CGRect {
        let zoneW = size.width * zoneWRatio
        let zoneH = size.height * zoneHRatio
        let usableTop = size.height * topOffsetRatio
        let usableH = size.height - usableTop
        let x = (size.width - zoneW) / 2
        var y = usableTop + (usableH - zoneH) / 2
        var h = zoneH

        // 凡例（枠の下 6pt に表示）が画面下端からはみ出さないよう、
        // 凡例の高さ + 下側の隙間 3pt を確保する。足りない場合は枠を上にずらし、
        // それでも足りなければ枠の高さを縮める。
        let legendGap: CGFloat = 6       // 枠と凡例の間
        let legendHeight: CGFloat = 44   // 凡例の高さ（余裕込み）
        let bottomGap: CGFloat = 3       // 凡例と画面下端の隙間
        let overflow = (y + h + legendGap + legendHeight + bottomGap) - size.height
        if overflow > 0 {
            let shift = min(overflow, y - usableTop)
            y -= shift
            h -= (overflow - shift)
        }

        // 位置の微調整：枠（と凡例）全体を下に 3pt ずらす。
        // 凡例の確保高さ 44pt は実寸（約 41pt）より余裕を持たせてあるので、凡例は画面内に収まる。
        let downShift: CGFloat = 3
        y += downShift
        return CGRect(x: x, y: y, width: zoneW, height: max(0, h))
    }

    /// 正規化座標（画像基準・左上原点）→ ビュー座標。プレビューは aspectFill なので同じ計算で合わせる。
    nonisolated static func transform(_ r: CGRect, imageSize: CGSize, viewSize: CGSize) -> CGRect? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let offX = (viewSize.width - imageSize.width * scale) / 2
        let offY = (viewSize.height - imageSize.height * scale) / 2

        var l = r.minX * imageSize.width * scale + offX
        var t = r.minY * imageSize.height * scale + offY
        var ri = r.maxX * imageSize.width * scale + offX
        var b = r.maxY * imageSize.height * scale + offY
        l = max(0, l); t = max(0, t)
        ri = min(viewSize.width, ri); b = min(viewSize.height, b)
        guard l < ri, t < b else { return nil }
        return CGRect(x: l, y: t, width: ri - l, height: b - t)
    }
}
