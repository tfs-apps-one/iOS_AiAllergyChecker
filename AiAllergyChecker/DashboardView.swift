//
//  DashboardView.swift
//  AiAllergyChecker
//
//  画面下部の「ALLERGEN MONITOR」。
//   ・9 品目モード ：3×3 の大きめチップ（日本語 + 英語）で下部いっぱいに表示
//   ・29 品目モード：「特定原材料など 9」「準ずるもの 20」の 2 セクション × 5 列のコンパクトチップ
//   ・検出のみ表示 ：検出された品目だけを大きなカードで表示
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 34)
                .padding(.leading, 4)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .background(
            LinearGradient(colors: [Theme.panelTop, Theme.panelBottom], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .top) {
            // 上端の細いハイライトライン
            LinearGradient(colors: [Theme.red.opacity(0), Theme.red.opacity(0.6), Theme.red.opacity(0)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            BlinkingLed(color: model.numActive > 0 ? Theme.ledAlert : Theme.ledScan)

            if !model.expanded {
                Text("ALLERGEN MONITOR")
                    .font(.system(size: 10, weight: .bold).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.leading, 7)
                    .fixedSize()
            }

            Text(countText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textMain)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            if model.expanded {
                Text("+20  \(formatHMS(model.remainingUnlock))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accentAmber)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Theme.accentAmber.opacity(0.15), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.accentAmber.opacity(0.8), lineWidth: 1))
                    .fixedSize()
            }

            // 【初回リリースでは非表示】設定画面（表示モード切替・拡張モード）は追加アップデートで解放予定
            // Button {
            //     model.showSettings = true
            // } label: {
            //     Image(systemName: "gearshape.fill")
            //         .font(.system(size: 18))
            //         .foregroundStyle(Theme.textMuted)
            //         .frame(width: 34, height: 34)
            //         .contentShape(Rectangle())
            // }
            // .padding(.leading, 4)
            // .accessibilityLabel("設定")
        }
    }

    private var countText: AttributedString {
        var s = AttributedString("\(model.visibleCount)品目")
        if model.numActive > 0 {
            var a = AttributedString("  ▲\(model.numActive)件検出")
            a.foregroundColor = Theme.accentRed
            s += a
        }
        return s
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.detectedOnly {
            DetectedOnlyList()
        } else if !model.expanded {
            // 9 品目：3×3 で下部いっぱい
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { c in
                            let i = r * 3 + c
                            AllergenChip(index: i, active: model.active[i], compact: false)
                                .padding(3)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        } else {
            // 29 品目：2 セクション × 5 列
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    SectionLabel(title: "特定原材料など", count: Allergens.basicCount, withLegend: false)
                    chipGrid(0..<Allergens.basicCount)
                    SectionLabel(title: "準ずるもの", count: Allergens.totalCount - Allergens.basicCount, withLegend: true)
                    chipGrid(Allergens.basicCount..<Allergens.totalCount)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func chipGrid(_ range: Range<Int>) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 5)
        return LazyVGrid(columns: cols, spacing: 0) {
            ForEach(Array(range), id: \.self) { i in
                AllergenChip(index: i, active: model.active[i], compact: true)
                    .frame(height: 30)
                    .padding(3)
            }
        }
    }
}

// MARK: - Chip

struct AllergenChip: View {
    let index: Int
    let active: Bool
    let compact: Bool

    @State private var scale: CGFloat = 1

    private var allergen: Allergen { Allergens.all[index] }

    var body: some View {
        let radius: CGFloat = compact ? 8 : 12
        HStack(spacing: compact ? 3 : 6) {
            Led(active: active, category: allergen.category, size: compact ? 6 : 8)

            if compact {
                Text(allergen.shortJa)
                    .font(.system(size: 12, weight: active ? .bold : .regular))
                    .foregroundStyle(active ? .white : Theme.textOff)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                VStack(spacing: 1) {
                    Text(allergen.nameJa)
                        .font(.system(size: allergen.nameJa.count >= 5 ? 11 : 15, weight: .bold))
                        .foregroundStyle(active ? .white : Theme.textOff)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(allergen.nameEn.uppercased())
                        .font(.system(size: 9.5))
                        .foregroundStyle(active ? Color.white.opacity(0.86) : Theme.textSubOff)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .padding(.horizontal, compact ? 4 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(chipBackground(radius: radius))
        .scaleEffect(scale)
        .onChange(of: active) { _, now in
            guard now else { return }
            pulse($scale, from: 1.10, duration: 0.22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(allergen.nameJa)\(active ? "、検出" : "")")
    }

    @ViewBuilder
    private func chipBackground(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        if active {
            shape.fill(LinearGradient(colors: [Theme.chipBgOnStart, Theme.chipBgOnEnd],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shape.stroke(Theme.chipStrokeOn, lineWidth: 1))
        } else {
            shape.fill(Theme.chipBgOff)
                .overlay(shape.stroke(Theme.chipStrokeOff, lineWidth: 1))
        }
    }
}

/// チップ内の LED：OFF = カテゴリ色を暗く / ON = 白く発光
struct Led: View {
    let active: Bool
    let category: AllergenCategory
    let size: CGFloat

    var body: some View {
        if active {
            Circle()
                .fill(.white)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.47), lineWidth: 2).frame(width: size + 3, height: size + 3))
                .shadow(color: .white.opacity(0.8), radius: 3)
        } else {
            Circle()
                .fill(Theme.categoryColor(category).opacity(0.59))
                .frame(width: size, height: size)
        }
    }
}

/// ヘッダーの LED：スキャン中は緑でゆっくり点滅、検出時は赤
struct BlinkingLed: View {
    let color: Color
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .opacity(dim ? 0.25 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

struct SectionLabel: View {
    let title: String
    let count: Int
    let withLegend: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(labelText)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            if withLegend {
                Text(legendText)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSubOff)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 1)
    }

    private var labelText: AttributedString {
        var s = AttributedString(title)
        var c = AttributedString("  \(count)")
        c.foregroundColor = withLegend ? Theme.accentAmber : Theme.accentRed
        s += c
        return s
    }

    private var legendText: AttributedString {
        var s = AttributedString()
        let cats: [AllergenCategory] = [.meat, .seafood, .nuts, .fruit, .other]
        for (k, c) in cats.enumerated() {
            var dot = AttributedString("●")
            dot.foregroundColor = Theme.categoryColor(c)
            s += dot
            s += AttributedString(c.label + (k < cats.count - 1 ? " " : ""))
        }
        return s
    }
}

// MARK: - Detected only

/// 検出のみ表示：検出された品目だけを大きな文字のカードで表示。
/// 1 件なら横幅いっぱい、2 件以上は 2 列（多い場合は 3 列）。
/// パネルの高さに合わせてカードの高さを自動調整し、iPhone SE のような小さい画面でも
/// 8 件程度までスクロールなしで一覧できるようにする。
struct DetectedOnlyList: View {
    @Environment(AppModel.self) private var model

    /// カード 1 枚の高さの上限・下限（余白を含まない）
    private let maxChipHeight: CGFloat = 66
    private let minChipHeight: CGFloat = 32
    private let cellPadding: CGFloat = 3

    var body: some View {
        let items = (0..<model.visibleCount).filter { model.active[$0] }
        if items.isEmpty {
            VStack(spacing: 8) {
                Text("対象品目は未検出")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textOff)
                Text("※ 最終判断は必ず原材料表示を目視で確認してください")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSubOff)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geo in
                let layout = fitLayout(count: items.count, available: geo.size.height)
                let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: layout.columns)
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: cols, spacing: 0) {
                        ForEach(items, id: \.self) { i in
                            BigChip(index: i, height: layout.chipHeight, columns: layout.columns)
                                .frame(height: layout.chipHeight)
                                .padding(cellPadding)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    /// 件数と使える高さから列数とカード高さを決める。
    /// 2 列で最小高さを下回る場合は 3 列にし、それでも収まらなければ最小高さでスクロールさせる。
    private func fitLayout(count: Int, available: CGFloat) -> (columns: Int, chipHeight: CGFloat) {
        if count == 1 {
            return (1, min(maxChipHeight, max(minChipHeight, available - cellPadding * 2)))
        }
        func height(for columns: Int) -> CGFloat {
            let rows = CGFloat((count + columns - 1) / columns)
            return floor(available / rows) - cellPadding * 2
        }
        let h2 = height(for: 2)
        if h2 >= minChipHeight {
            return (2, min(maxChipHeight, h2))
        }
        let h3 = height(for: 3)
        return (3, min(maxChipHeight, max(minChipHeight, h3)))
    }
}

struct BigChip: View {
    let index: Int
    var height: CGFloat = 66
    var columns: Int = 2
    @State private var scale: CGFloat = 1

    /// 高さが十分あるときは日本語・英語の 2 段、低いときは横並び 1 段
    private var twoLines: Bool { height >= 52 }

    var body: some View {
        let a = Allergens.all[index]
        let shape = RoundedRectangle(cornerRadius: height >= 52 ? 12 : 9)
        let jaSize: CGFloat = twoLines ? min(30, height * 0.45) : min(24, height * 0.62)
        HStack(spacing: twoLines ? 10 : 6) {
            Led(active: true, category: a.category, size: twoLines ? 8 : 6)
            if twoLines {
                VStack(spacing: 0) {
                    Text(a.nameJa)
                        .font(.system(size: jaSize, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                    Text(a.nameEn.uppercased())
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .lineLimit(1)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(a.nameJa)
                        .font(.system(size: jaSize, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .layoutPriority(1)
                    if columns <= 2 {
                        Text(a.nameEn.uppercased())
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, twoLines ? 10 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            shape.fill(LinearGradient(colors: [Theme.chipBgOnStart, Theme.chipBgOnEnd],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shape.stroke(Theme.chipStrokeOn, lineWidth: 1))
        )
        .scaleEffect(scale)
        .onAppear { pulse($scale, from: 1.08, duration: 0.24) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(a.nameJa)、検出")
    }
}

/// 点灯した瞬間の軽いパルス
@MainActor
func pulse(_ scale: Binding<CGFloat>, from: CGFloat, duration: Double) {
    var t = Transaction()
    t.disablesAnimations = true
    withTransaction(t) { scale.wrappedValue = from }
    Task { @MainActor in
        withAnimation(.easeOut(duration: duration)) { scale.wrappedValue = 1 }
    }
}
