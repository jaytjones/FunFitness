//
//  TrackWorkoutView.swift
//  FunFitness
//
//  Full-screen live walk/run tracking (3.1 B1a): pick Walk or Run → live time, distance, pace and
//  route map with Pause/Resume/Finish → summary with the whole route → Save or Discard. Saving goes
//  through `ActivityWriter.logTracked`, so milestones, streaks, and the widget update as usual.
//  "Hide" closes the screen while tracking continues; Home's card brings it back.
//

import SwiftUI
import SwiftData
import MapKit

struct TrackWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Bindable var viewModel: AppViewModel

    private let tracker = WorkoutTracker.shared
    @State private var selectedKind: TrackedWorkoutKind = .walk
    @State private var showFinishConfirm = false
    @State private var showDiscardConfirm = false
    // Outdoor surface for the saved run; prefilled from the last one used. (3.1)
    @State private var surface: DistanceSurface?
    // Avg/max read from Health once the summary opens; nil when nothing was recorded. (3.1 B2)
    @State private var heartRate: HeartRateSummary?

    /// Heart rate is read only for people who've turned on a Health option, so a run never
    /// triggers a surprise Health prompt.
    private var readsHeartRate: Bool {
        guard let profile = profiles.first else { return false }
        return profile.healthKitImportEnabled || profile.healthKitWriteBackEnabled
    }

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ffBg.ignoresSafeArea()

                switch tracker.phase {
                case .idle:
                    startScreen
                case .active, .paused:
                    liveScreen
                case .finished:
                    if let result = tracker.result {
                        summaryScreen(result)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    private var title: String {
        switch tracker.phase {
        case .idle:              return "Track a Walk or Run"
        case .active, .paused:   return tracker.kind.displayName
        case .finished:          return "Nice \(tracker.kind.displayName.lowercased())!"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            switch tracker.phase {
            case .idle:
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ffInkMuted)
                }
                .accessibilityLabel("Close")
            case .active, .paused:
                // Tracking keeps going; Home's tracking card reopens this screen.
                Button("Hide") { dismiss() }
                    .foregroundStyle(Color.ffLink)
                    .accessibilityHint("Keeps tracking in the background")
                    .accessibilityIdentifier("trackerHideButton")
            case .finished:
                EmptyView()
            }
        }
    }

    // MARK: - Start

    private var startScreen: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            Text(selectedKind.emoji)
                .font(.system(size: 80))
                .accessibilityHidden(true)

            Picker("Workout", selection: $selectedKind) {
                ForEach(TrackedWorkoutKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .accessibilityIdentifier("trackerKindPicker")

            Text("Uses GPS to measure your route. Tracking continues with the screen locked.")
                .ffFont(.body)
                .foregroundStyle(Color.ffInkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 0)

            // One live session at a time (they share the Live Activity).
            let strengthRunning = StrengthSessionManager.shared.phase != .idle
            if strengthRunning {
                Text("End your strength session before starting a walk or run.")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                WorkoutLiveActivityController.shared.configure(pref: pref, packId: viewModel.activePack.id)
                tracker.start(kind: selectedKind)
            } label: {
                Text("Start \(selectedKind.displayName)")
            }
            .buttonStyle(.ffPrimary)
            .disabled(strengthRunning)
            .padding(.horizontal)
            .padding(.bottom)
            .accessibilityIdentifier("trackerStartButton")
        }
    }

    // MARK: - Live

    private var liveScreen: some View {
        VStack(spacing: 0) {
            RouteMapView(points: tracker.points.map { ($0.latitude, $0.longitude) }, followsUser: true)
                .frame(maxHeight: .infinity)

            VStack(spacing: 16) {
                if let issue = tracker.locationIssue {
                    Label(issue, systemImage: "location.slash")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !tracker.hasLocationFix {
                    Label("Finding GPS…", systemImage: "location.magnifyingglass")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Ticks once a second for the clock and pace; distance changes on each GPS fix.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = tracker.movingSeconds(at: context.date)
                    LiveStatsGrid(
                        elapsed: UnitConverter.elapsedString(seconds),
                        distance: UnitConverter.distanceString(tracker.distanceMeters / 1000, pref: pref),
                        pace: UnitConverter.paceString(
                            secondsPerKm: RouteMath.paceSecondsPerKm(distanceMeters: tracker.distanceMeters, movingSeconds: seconds),
                            pref: pref
                        )
                    )
                }

                if tracker.phase == .paused {
                    Text("Paused")
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffInkMuted)
                }

                HStack(spacing: 16) {
                    Button {
                        tracker.phase == .paused ? tracker.resume() : tracker.pause()
                    } label: {
                        Label(tracker.phase == .paused ? "Resume" : "Pause",
                              systemImage: tracker.phase == .paused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.ffSecondary)
                    .accessibilityIdentifier("trackerPauseButton")

                    Button {
                        showFinishConfirm = true
                    } label: {
                        Label("Finish", systemImage: "flag.checkered")
                    }
                    .buttonStyle(.ffPrimary)
                    .accessibilityIdentifier("trackerFinishButton")
                }
            }
            .padding()
            .background(Color.ffSurface)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.ffLine).frame(height: FFStroke.card)
            }
        }
        .confirmationDialog("Finish this \(tracker.kind.displayName.lowercased())?",
                            isPresented: $showFinishConfirm, titleVisibility: .visible) {
            Button("Finish") { tracker.finish() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: - Summary

    private func summaryScreen(_ result: TrackedWorkoutResult) -> some View {
        let distanceKm = result.distanceMeters / 1000
        return ScrollView {
            VStack(spacing: 20) {
                RouteMapView(points: result.points.map { ($0.latitude, $0.longitude) }, followsUser: false)
                    .frame(height: 280)
                    .clipShape(.rect(cornerRadius: FFRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
                            .strokeBorder(Color.ffLine, lineWidth: FFStroke.card)
                    )

                LiveStatsGrid(
                    elapsed: UnitConverter.elapsedString(result.movingSeconds),
                    distance: UnitConverter.distanceString(distanceKm, pref: pref),
                    pace: UnitConverter.paceString(
                        secondsPerKm: RouteMath.paceSecondsPerKm(distanceMeters: result.distanceMeters, movingSeconds: result.movingSeconds),
                        pref: pref
                    )
                )
                .ffCard(padding: FFSpace.s4, radius: FFRadius.md)

                if let heartRate {
                    HeartRateCard(summary: heartRate)
                }

                if let phrase = viewModel.comparisonPhrase(distanceKm: distanceKm) {
                    Text(phrase)
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffOnAccent2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .ffCard(padding: FFSpace.s4, radius: FFRadius.md, fill: .ffAccent2)
                }

                SurfacePicker(selection: $surface, options: DistanceSurface.outdoor)
                    .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
                    .onAppear {
                        if surface == nil, let last = viewModel.lastSurface, DistanceSurface.outdoor.contains(last) {
                            surface = last
                        }
                    }

                if !result.isSavable {
                    Text("That's too short to save — GPS may not have found you. You can discard it and try again outdoors.")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                        .multilineTextAlignment(.center)
                }

                Button { save(result) } label: {
                    Text("Save \(result.kind.displayName)")
                }
                .buttonStyle(.ffPrimary)
                .disabled(!result.isSavable)
                .accessibilityIdentifier("trackerSaveButton")

                Button("Discard", role: .destructive) { showDiscardConfirm = true }
                    .ffFont(.bodyStrong)
                    .foregroundStyle(Color.ffDanger)
                    .accessibilityIdentifier("trackerDiscardButton")
            }
            .padding()
        }
        .task(id: result.startedAt) {
            guard readsHeartRate else { return }
            heartRate = await HealthKitManager.shared.heartRateSummary(for: result)
        }
        .confirmationDialog("Discard this \(result.kind.displayName.lowercased())?",
                            isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                tracker.reset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func save(_ result: TrackedWorkoutResult) {
        // Celebrations wait for this cover to close (ContentView's onDismiss shows them).
        viewModel.deferredMilestones += ActivityWriter.logTracked(
            result,
            surface: surface,
            heartRate: heartRate,
            readsHeartRate: readsHeartRate,
            context: modelContext,
            viewModel: viewModel,
            writeBackToHealth: profiles.first?.healthKitWriteBackEnabled ?? false
        )
        tracker.reset()
        dismiss()
    }
}

// MARK: - Stats

private struct LiveStatsGrid: View {
    let elapsed: String
    let distance: String
    let pace: String

    var body: some View {
        HStack(alignment: .top) {
            stat("Time", elapsed)
            stat("Distance", distance)
            stat("Pace", pace)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .ffFont(.numeral)
                .foregroundStyle(Color.ffInk)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// "♥ 132 avg · 158 max bpm" on a finished walk/run's summary. (3.1 B2)
private struct HeartRateCard: View {
    let summary: HeartRateSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(Color.ffDanger)
                .accessibilityHidden(true)
            stat("Avg Heart Rate", summary.averageText)
            stat("Max Heart Rate", summary.maximumText)
        }
        .frame(maxWidth: .infinity)
        .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
    }

    private func stat(_ label: String, _ bpm: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(bpm)
                    .ffFont(.title)
                    .foregroundStyle(Color.ffInk)
                Text("bpm")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }
            Text(label)
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(bpm) beats per minute")
    }
}

// MARK: - Route map

/// Draws a route polyline. Live, it follows the user; in a summary, it frames the whole route.
struct RouteMapView: View {
    let points: [(latitude: Double, longitude: Double)]
    let followsUser: Bool

    @State private var position: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Color.ffAccent2, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if followsUser {
                UserAnnotation()
            } else if let first = coordinates.first, let last = coordinates.last {
                Annotation("Start", coordinate: first) {
                    Circle().fill(Color.ffSuccess).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2))
                }
                Annotation("Finish", coordinate: last) {
                    Circle().fill(Color.ffDanger).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapControls {
            if followsUser { MapUserLocationButton() }
        }
        .onAppear {
            if followsUser {
                position = .userLocation(followsHeading: false, fallback: .automatic)
            }
        }
        .accessibilityLabel(followsUser ? "Live route map" : "Route map")
    }
}

#Preview {
    TrackWorkoutView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self, UserProfile.self, RouteSummary.self], inMemory: true)
}
