//
//  WorkoutLiveActivityWidget.swift
//  FunFitnessWidgets
//
//  Lock Screen and Dynamic Island UI for a tracked walk/run (3.1 B1b) or a strength session (B1c).
//  Clocks run on their own with `Text(timerInterval:)`; stats and the comparison line come
//  pre-formatted from the app. Buttons are `LiveActivityIntent`s the app handles: Pause/Resume +
//  End for walks/runs, Log Set + End for strength.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
                .activityBackgroundTint(Color.ffSurface)
                .activitySystemActionForegroundColor(Color.ffInk)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.title)
                    } icon: {
                        Text(context.attributes.emoji)
                    }
                    .ffFont(.headline)
                    .foregroundStyle(IslandStyle.ink)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // The rest countdown (reps orange) takes the clock's place between strength
                    // sets, keeping the expanded island to two rows below the header.
                    CompactTimer(state: context.state)
                        .ffFont(.headline)
                        .foregroundStyle(context.state.restEnd == nil ? Color.ffAccent : Color.ffTypeReps)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: FFSpace.s2) {
                        WorkoutStatsRow(state: context.state, inIsland: true)
                        WorkoutControls(isStrength: context.attributes.isStrength, state: context.state, inIsland: true)
                    }
                }
            } compactLeading: {
                // Walks/runs pair a pink dot with distance so the compact island shows both
                // distance (leading) and time (trailing) at a glance.
                if context.attributes.isStrength {
                    Text(context.attributes.emoji)
                } else {
                    HStack(spacing: FFSpace.s1) {
                        Circle()
                            .fill(Color.ffAccent)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(context.state.primaryValue)
                            .font(.system(.caption, design: .rounded, weight: .bold).monospacedDigit())
                            .foregroundStyle(IslandStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            } compactTrailing: {
                // While resting between sets, the rest countdown matters more than the session clock.
                CompactTimer(state: context.state)
                    .font(.system(.caption, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(context.state.restEnd == nil ? Color.ffAccent : Color.ffTypeReps)
                    .frame(maxWidth: 52)
            } minimal: {
                // The minimal island (shown when another app's Live Activity shares the island)
                // only fits one short value: distance for walks/runs, the emoji for strength.
                if context.attributes.isStrength {
                    Text(context.attributes.emoji)
                } else {
                    Text(context.state.primaryValue)
                        .font(.system(.caption2, design: .rounded, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.ffAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .keylineTint(Color.ffAccent)
        }
    }
}

// MARK: - Lock Screen

/// Playful Bold Lock Screen card (LiveActivity.md): `surface` ground following the system
/// appearance, the outlined title tag, the clock as the largest element. No offset shadows.
private struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpace.s2) {
            HStack(spacing: FFSpace.s2) {
                Text(context.attributes.emoji)
                    .font(.headline)
                FFTag(
                    text: context.attributes.title,
                    fill: context.attributes.isStrength ? .ffTypeWeight : .ffTypeDistance,
                    foreground: context.attributes.isStrength ? .ffOnTypeWeight : .ffOnTypeDistance
                )
                if context.state.isPaused {
                    FFTag(text: String(localized: "Paused"), fill: .ffSurfaceAlt, foreground: .ffInk)
                } else if context.state.isFinished {
                    FFTag(text: String(localized: "Finished"), fill: .ffSurface, foreground: .ffSuccess)
                }
                Spacer()
                WorkoutClock(state: context.state)
                    .ffFont(.title)
                    .foregroundStyle(context.state.isPaused ? Color.ffInkMuted : Color.ffInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            WorkoutStatsRow(state: context.state, inIsland: false)

            // One line here to fit the Lock Screen's height: the rest countdown while resting
            // between strength sets, otherwise the comparison.
            if context.state.restEnd != nil {
                RestCountdown(state: context.state)
            } else if let comparison = context.state.comparison {
                Text(comparison)
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            WorkoutControls(isStrength: context.attributes.isStrength, state: context.state, inIsland: false)
        }
        .padding(FFSpace.s4)
        // Painted here as well as via activityBackgroundTint so the ink text always has its
        // surface ground, whatever tint treatment the system applies.
        .background(Color.ffSurface)
    }
}

// MARK: - Pieces

/// The Dynamic Island is always black (`island`, drawn by iOS); its text is `island-ink`.
/// Style.swift has no Swift token for island-ink, so its tokens.json value (#FFFFFF) lives here.
private enum IslandStyle {
    static let ink = Color.white
}

/// Ticks live while moving; frozen while paused or finished.
private struct WorkoutClock: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if state.isPaused || state.isFinished {
            Text(state.elapsedText)
        } else {
            Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// The Dynamic Island's clock: the rest countdown while resting, else the session clock.
private struct CompactTimer: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if let restStart = state.restStart, let restEnd = state.restEnd {
            Text(timerInterval: restStart...restEnd, countsDown: true)
                .multilineTextAlignment(.trailing)
        } else {
            WorkoutClock(state: state)
        }
    }
}

/// "Rest 1:12" between strength sets. Counts down on its own; nothing shows outside a rest.
private struct RestCountdown: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if let restStart = state.restStart, let restEnd = state.restEnd {
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .foregroundStyle(Color.ffTypeReps)
                    .accessibilityHidden(true)
                Text("Rest")
                Text(timerInterval: restStart...restEnd, countsDown: true)
                    .monospacedDigit()
            }
            .ffFont(.caption)
            .foregroundStyle(Color.ffInk)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WorkoutStatsRow: View {
    let state: WorkoutActivityAttributes.ContentState
    let inIsland: Bool

    var body: some View {
        HStack {
            stat(state.primaryLabel, state.primaryValue)
            Spacer()
            stat(state.secondaryLabel, state.secondaryValue)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .ffFont(.headline)
                .foregroundStyle(inIsland ? IslandStyle.ink : Color.ffInk)
            Text(label)
                .ffFont(.label)
                .foregroundStyle(inIsland ? IslandStyle.ink.opacity(0.7) : Color.ffInkMuted)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WorkoutControls: View {
    let isStrength: Bool
    let state: WorkoutActivityAttributes.ContentState
    let inIsland: Bool

    var body: some View {
        if !state.isFinished {
            HStack(spacing: FFSpace.s3) {
                if isStrength {
                    // Repeats the last set; nothing to repeat until the first set is in.
                    if state.canLogSet {
                        Button(intent: LogSetIntent()) {
                            Label("Log Set", systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiveActivityPillStyle(kind: .secondary, inIsland: inIsland))
                    }
                } else if state.isPaused {
                    Button(intent: ResumeWorkoutIntent()) {
                        Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiveActivityPillStyle(kind: .secondary, inIsland: inIsland))
                } else {
                    Button(intent: PauseWorkoutIntent()) {
                        Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiveActivityPillStyle(kind: .secondary, inIsland: inIsland))
                }
                Button(intent: EndWorkoutIntent()) {
                    Label("End", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                }
                .buttonStyle(LiveActivityPillStyle(kind: .primary, inIsland: inIsland))
            }
        }
    }
}

/// Playful Bold pill for Live Activity buttons: `.primary` is the pink accent (End), `.secondary`
/// a surface pill (Pause/Resume/Log Set). Outlined on the Lock Screen; no outlines in the Dynamic
/// Island. No offset shadow on either (iOS clips them). Sized like the old bordered buttons so
/// the Lock Screen height is unchanged.
private struct LiveActivityPillStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind
    let inIsland: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.vertical, 7)
            .padding(.horizontal, FFSpace.s3)
            .background(background, in: .capsule)
            .overlay {
                if !inIsland {
                    Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(.capsule)
    }

    private var background: Color {
        switch kind {
        case .primary: return .ffAccent
        case .secondary: return inIsland ? IslandStyle.ink.opacity(0.2) : .ffSurface
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .ffOnAccent
        case .secondary: return inIsland ? IslandStyle.ink : .ffInk
        }
    }
}

// MARK: - Previews

private extension WorkoutActivityAttributes {
    static let preview = WorkoutActivityAttributes(title: "Walk", emoji: "🚶")
    static let strengthPreview = WorkoutActivityAttributes(title: "Strength", emoji: "🏋️", isStrength: true)
}

private extension WorkoutActivityAttributes.ContentState {
    static let moving = WorkoutActivityAttributes.ContentState(
        isPaused: false, isFinished: false, timerStart: .now.addingTimeInterval(-725),
        elapsedText: "12:05", primaryValue: "0.8 mi", primaryLabel: "Distance",
        secondaryValue: "15:06 /mi", secondaryLabel: "Pace",
        comparison: "0.8 mi is 2 blue whales 🐋"
    )
    static let paused = WorkoutActivityAttributes.ContentState(
        isPaused: true, isFinished: false, timerStart: .now.addingTimeInterval(-725),
        elapsedText: "12:05", primaryValue: "0.8 mi", primaryLabel: "Distance",
        secondaryValue: "15:06 /mi", secondaryLabel: "Pace",
        comparison: "0.8 mi is 2 blue whales 🐋"
    )
    static let resting = WorkoutActivityAttributes.ContentState(
        isPaused: false, isFinished: false, timerStart: .now.addingTimeInterval(-1_260),
        elapsedText: "21:00", primaryValue: "4", primaryLabel: "Sets",
        secondaryValue: "135 lbs × 10", secondaryLabel: "Last set",
        comparison: "5,400 lbs lifted — 1 hippo 🦛",
        restStart: .now.addingTimeInterval(-18), restEnd: .now.addingTimeInterval(72), canLogSet: true
    )
    static let finished = WorkoutActivityAttributes.ContentState(
        isPaused: false, isFinished: true, timerStart: .now.addingTimeInterval(-1_830),
        elapsedText: "30:30", primaryValue: "2.0 mi", primaryLabel: "Distance",
        secondaryValue: "15:15 /mi", secondaryLabel: "Pace",
        comparison: "Open FunFitness to save it"
    )
}

#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutActivityAttributes.ContentState.moving
    WorkoutActivityAttributes.ContentState.paused
    WorkoutActivityAttributes.ContentState.finished
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutActivityAttributes.ContentState.moving
}

#Preview("Compact", as: .dynamicIsland(.compact), using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutActivityAttributes.ContentState.moving
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutActivityAttributes.ContentState.moving
}

#Preview("Strength", as: .content, using: WorkoutActivityAttributes.strengthPreview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutActivityAttributes.ContentState.resting
}

#Preview("Strength Expanded", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes.strengthPreview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutActivityAttributes.ContentState.resting
}
