//
//  WorkoutLiveActivityWidget.swift
//  FunFitnessWidgets
//
//  Lock Screen and Dynamic Island UI for a tracked walk/run (3.1 B1b). The clock runs on its own
//  with `Text(timerInterval:)`; distance, pace, and the comparison line come pre-formatted from
//  the app. Pause/Resume and End are `LiveActivityIntent` buttons the app handles.
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
                    WorkoutClock(state: context.state)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(WorkoutLiveActivityStyle.accent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        WorkoutStatsRow(state: context.state)
                        WorkoutControls(state: context.state)
                    }
                }
            } compactLeading: {
                Text(context.attributes.emoji)
            } compactTrailing: {
                WorkoutClock(state: context.state)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(WorkoutLiveActivityStyle.accent)
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
        VStack(alignment: .leading, spacing: 10) {
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

            if let comparison = context.state.comparison {
                Text(comparison)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            WorkoutControls(state: context.state)
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
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if !state.isFinished {
            HStack(spacing: 12) {
                if state.isPaused {
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
