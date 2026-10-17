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
                .activityBackgroundTint(WorkoutLiveActivityStyle.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.title)
                    } icon: {
                        Text(context.attributes.emoji)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // The rest countdown (orange) takes the clock's place between strength sets,
                    // keeping the expanded island to two rows below the header.
                    CompactTimer(state: context.state)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(context.state.restEnd == nil ? WorkoutLiveActivityStyle.accent : .orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        WorkoutStatsRow(state: context.state)
                        WorkoutControls(isStrength: context.attributes.isStrength, state: context.state)
                    }
                }
            } compactLeading: {
                Text(context.attributes.emoji)
            } compactTrailing: {
                // While resting between sets, the rest countdown matters more than the session clock.
                CompactTimer(state: context.state)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(context.state.restEnd == nil ? WorkoutLiveActivityStyle.accent : .orange)
                    .frame(maxWidth: 52)
            } minimal: {
                Text(context.attributes.emoji)
            }
            .keylineTint(WorkoutLiveActivityStyle.accent)
        }
    }
}

// MARK: - Lock Screen

private struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(context.attributes.emoji) \(context.attributes.title)")
                    .font(.headline)
                    .foregroundStyle(.white)
                if context.state.isPaused {
                    Text("Paused")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if context.state.isFinished {
                    Text("Finished")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                Spacer()
                WorkoutClock(state: context.state)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(WorkoutLiveActivityStyle.accent)
            }

            WorkoutStatsRow(state: context.state)

            // One line here to fit the Lock Screen's height: the rest countdown while resting
            // between strength sets, otherwise the comparison.
            if context.state.restEnd != nil {
                RestCountdown(state: context.state)
            } else if let comparison = context.state.comparison {
                Text(comparison)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            WorkoutControls(isStrength: context.attributes.isStrength, state: context.state)
        }
        .padding()
        // Painted here as well as via activityBackgroundTint so the white text always has its
        // dark background, whatever tint treatment the system applies.
        .background(WorkoutLiveActivityStyle.background)
    }
}

// MARK: - Pieces

private enum WorkoutLiveActivityStyle {
    static let background = Color(red: 0.12, green: 0.11, blue: 0.20)
    static let accent     = Color(red: 0.65, green: 0.55, blue: 0.98)   // #A78BFA
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
                    .accessibilityHidden(true)
                Text("Rest")
                Text(timerInterval: restStart...restEnd, countsDown: true)
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WorkoutStatsRow: View {
    let state: WorkoutActivityAttributes.ContentState

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
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WorkoutControls: View {
    let isStrength: Bool
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if !state.isFinished {
            HStack(spacing: 12) {
                if isStrength {
                    // Repeats the last set; nothing to repeat until the first set is in.
                    if state.canLogSet {
                        Button(intent: LogSetIntent()) {
                            Label("Log Set", systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .tint(.green)
                    }
                } else if state.isPaused {
                    Button(intent: ResumeWorkoutIntent()) {
                        Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .tint(.green)
                } else {
                    Button(intent: PauseWorkoutIntent()) {
                        Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                    }
                    .tint(.orange)
                }
                Button(intent: EndWorkoutIntent()) {
                    Label("End", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                }
                .tint(WorkoutLiveActivityStyle.accent)
            }
            .buttonStyle(.borderedProminent)
            .font(.subheadline.weight(.semibold))
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
