//
//  FieldGuideCharts.swift
//  FunFitness
//
//  Field Guide's Progress figures (3.3): weekly volume as a stem chart (ink stems ending in a
//  type-colour dot, open circles for zero weeks, values over each stem) and the 12-week heatmap
//  as hairline cells stippled with 1 or 3 ink dots — density by dot count, so it reads in both
//  appearances and in greyscale. Spec: docs/design/field-guide/components/ProgressCharts.md.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI
import Charts

struct FieldGuideStemChart: View {
    let buckets: [AnalyticsEngine.WeeklyBucket]
    let type: ActivityType
    let pref: UnitPreference

    var body: some View {
        let unit = UnitConverter.displayUnit(for: type, pref: pref)
        Chart(buckets) { bucket in
            let value = UnitConverter.fromSI(bucket.total, type: type, to: pref)
            if bucket.total > 0 {
                RuleMark(
                    x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                    yStart: .value(unit, 0),
                    yEnd: .value(unit, value)
                )
                .foregroundStyle(Color.ffInk)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                PointMark(
                    x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                    y: .value(unit, value)
                )
                .symbolSize(70)
                .foregroundStyle(type.ffFill)
                .annotation(position: .top, spacing: 4) {
                    Text(verbatim: value.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.ffInkMuted)
                }
            } else {
                // Zero weeks: an open circle on the axis.
                PointMark(
                    x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                    y: .value(unit, 0)
                )
                .symbol(Circle().strokeBorder(lineWidth: 1.2))
                .symbolSize(50)
                .foregroundStyle(Color.ffInk)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisTick().foregroundStyle(Color.ffLine)
                AxisValueLabel().font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.ffInkMuted)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.ffLine.opacity(0.25))
                AxisValueLabel().font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.ffInkMuted)
            }
        }
        .frame(height: 170)
        .accessibilityLabel(Text(verbatim: "Weekly \(type.displayName.lowercased()), last 8 weeks: "
            + buckets.map { UnitConverter.fromSI($0.total, type: type, to: pref).formatted(.number.precision(.fractionLength(0...1))) }.joined(separator: ", ")
            + " \(unit)"))
    }
}

/// One heatmap day: a hairline cell with 0, 1 or 3 ink dots.
struct FieldGuideStippleCell: View {
    let count: Int
    var size: CGFloat = 14

    var body: some View {
        Canvas { context, canvasSize in
            let dots = count == 0 ? 0 : (count == 1 ? 1 : 3)
            let r: CGFloat = 1.4
            let points: [CGPoint]
            switch dots {
            case 1: points = [CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)]
            case 3: points = [CGPoint(x: canvasSize.width * 0.3, y: canvasSize.height * 0.32),
                              CGPoint(x: canvasSize.width * 0.7, y: canvasSize.height * 0.45),
                              CGPoint(x: canvasSize.width * 0.4, y: canvasSize.height * 0.72)]
            default: points = []
            }
            for p in points {
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.ffInk))
            }
        }
        .frame(width: size, height: size)
        .overlay(Rectangle().strokeBorder(Color.ffLine.opacity(0.6), lineWidth: 0.75))
    }
}

#endif
