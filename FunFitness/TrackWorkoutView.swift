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

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

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
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            case .active, .paused:
                // Tracking keeps going; Home's tracking card reopens this screen.
                Button("Hide") { dismiss() }
                    .foregroundStyle(Color(hex: "#A78BFA"))
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 0)

            // One live session at a time (they share the Live Activity).
            let strengthRunning = StrengthSessionManager.shared.phase != .idle
            if strengthRunning {
                Text("End your strength session before starting a walk or run.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                WorkoutLiveActivityController.shared.configure(pref: pref, packId: viewModel.activePack.id)
                tracker.start(kind: selectedKind)
            } label: {
                Text("Start \(selectedKind.displayName)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(hex: "#059669").opacity(strengthRunning ? 0.4 : 1))
                    .clipShape(.capsule)
            }
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
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !tracker.hasLocationFix {
                    Label("Finding GPS…", systemImage: "location.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        .font(.headline)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 16) {
                    Button {
                        tracker.phase == .paused ? tracker.resume() : tracker.pause()
                    } label: {
                        Label(tracker.phase == .paused ? "Resume" : "Pause",
                              systemImage: tracker.phase == .paused ? "play.fill" : "pause.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: tracker.phase == .paused ? "#059669" : "#D97706"))
                            .clipShape(.capsule)
                    }
                    .accessibilityIdentifier("trackerPauseButton")

                    Button {
                        showFinishConfirm = true
                    } label: {
                        Label("Finish", systemImage: "flag.checkered")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#5B21B6"))
                            .clipShape(.capsule)
                    }
                    .accessibilityIdentifier("trackerFinishButton")
                }
            }
            .padding()
            .background(Color.appCard)
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
                    .clipShape(.rect(cornerRadius: 20))

                LiveStatsGrid(
                    elapsed: UnitConverter.elapsedString(result.movingSeconds),
                    distance: UnitConverter.distanceString(distanceKm, pref: pref),
                    pace: UnitConverter.paceString(
                        secondsPerKm: RouteMath.paceSecondsPerKm(distanceMeters: result.distanceMeters, movingSeconds: result.movingSeconds),
                        pref: pref
                    )
                )
                .padding()
                .background(Color.appCard)
                .clipShape(.rect(cornerRadius: 20))

                if let phrase = viewModel.comparisonPhrase(distanceKm: distanceKm) {
                    Text(phrase)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#D946EF")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(.rect(cornerRadius: 20))
                }

                SurfacePicker(selection: $surface, options: DistanceSurface.outdoor)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .clipShape(.rect(cornerRadius: 20))
                    .onAppear {
                        if surface == nil, let last = viewModel.lastSurface, DistanceSurface.outdoor.contains(last) {
                            surface = last
                        }
                    }

                if !result.isSavable {
                    Text("That's too short to save — GPS may not have found you. You can discard it and try again outdoors.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button { save(result) } label: {
                    Text("Save \(result.kind.displayName)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#5B21B6").opacity(result.isSavable ? 1 : 0.4))
                        .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(!result.isSavable)
                .accessibilityIdentifier("trackerSaveButton")

                Button("Discard", role: .destructive) { showDiscardConfirm = true }
                    .accessibilityIdentifier("trackerDiscardButton")
            }
            .padding()
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
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
                    .stroke(Color(hex: "#A78BFA"), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if followsUser {
                UserAnnotation()
            } else if let first = coordinates.first, let last = coordinates.last {
                Annotation("Start", coordinate: first) {
                    Circle().fill(.green).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2))
                }
                Annotation("Finish", coordinate: last) {
                    Circle().fill(.red).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2))
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
