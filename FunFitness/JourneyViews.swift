//
//  JourneyViews.swift
//  FunFitness
//
//  Journey Mode UI (3.1): the Home card, a detail screen with the map and checkpoints, and the
//  journey picker. The math lives in JourneyEngine.
//

import SwiftUI
import SwiftData
import MapKit

/// Shared lookups for the journey views.
@MainActor
private enum JourneyState {
    static func active(_ profile: UserProfile?) -> Journey? {
        profile.flatMap { JourneyCatalog.journey(id: $0.activeJourneyID) }
    }

    static func progress(_ journey: Journey, profile: UserProfile?, activities: [ActivityLog]) -> JourneyProgress {
        let start = profile?.journeyStartedAt ?? .distantPast
        let entries = activities
            .filter { $0.activityType == .distance }
            .map { (date: $0.loggedAt, km: $0.value) }
        return JourneyEngine.progress(journey: journey, distanceKm: JourneyEngine.distanceSince(start, entries: entries))
    }
}

// MARK: - Home card

struct JourneyCard: View {
    @Query private var profiles: [UserProfile]
    let viewModel: AppViewModel

    @State private var showDetail = false
    @State private var showPicker = false

    private var pref: UnitPreference { viewModel.unitPreference }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Group {
            if let journey = JourneyState.active(profile) {
                activeCard(JourneyState.progress(journey, profile: profile, activities: viewModel.activities))
            } else {
                startCard
            }
        }
        .sheet(isPresented: $showDetail) {
            JourneyDetailView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPicker) {
            JourneyPickerSheet()
        }
    }

    private func activeCard(_ progress: JourneyProgress) -> some View {
        let covered = UnitConverter.displayString(progress.distanceKm, type: .distance, pref: pref)
        let total = UnitConverter.displayString(progress.journey.totalKm, type: .distance, pref: pref)
        let nextText: String = progress.next.map {
            "Next: \($0.name) in \(UnitConverter.displayString(progress.kmToNext, type: .distance, pref: pref))"
        } ?? "Journey complete! 🎉"

        return Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(progress.journey.emoji)
                        .font(.title)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Journey · \(progress.journey.name)")
                            .ffFont(.label)
                            .foregroundStyle(Color.ffInkMuted)
                        Text(progress.latest.map { progress.isComplete ? "Finished at \($0.name)" : "Passed \($0.name)" } ?? progress.journey.name)
                            .ffFont(.headline)
                            .foregroundStyle(Color.ffInk)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.ffInkMuted)
                }

                // Journeys only count distance, so the meter uses the distance type color.
                SwiftUI.ProgressView(value: progress.fraction)
                    .progressViewStyle(FFMeterStyle(fill: ActivityType.distance.ffFill))

                HStack {
                    Text(nextText)
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInk)
                    Spacer()
                    Text("\(covered) / \(total)")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInk)
                }
            }
            .ffCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress.journey.name) journey: \(covered) of \(total). \(nextText)")
        .accessibilityHint("Shows the map and checkpoints")
        .accessibilityIdentifier("journeyCard")
    }

    private var startCard: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 12) {
                Text("🗺️")
                    .font(.title)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a Journey")
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffInk)
                    Text("Walk the Texas Triangle or the Appalachian Trail, one logged mile at a time.")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.ffInkMuted)
            }
            .ffCard(padding: FFSpace.s4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("startJourneyCard")
    }
}

// MARK: - Detail

struct JourneyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    let viewModel: AppViewModel

    @State private var showPicker = false

    private var pref: UnitPreference { viewModel.unitPreference }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Group {
                if let journey = JourneyState.active(profile) {
                    content(JourneyState.progress(journey, profile: profile, activities: viewModel.activities))
                } else {
                    ContentUnavailableView("No Journey", systemImage: "map", description: Text("Pick a journey to start."))
                }
            }
            .background(Color.ffBg)
            .navigationTitle(JourneyState.active(profile)?.name ?? "Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Switch") { showPicker = true }
                        .accessibilityLabel("Switch journey")
                }
            }
            .sheet(isPresented: $showPicker) {
                JourneyPickerSheet()
            }
        }
    }

    private func content(_ progress: JourneyProgress) -> some View {
        List {
            Section {
                JourneyMap(progress: progress)
                    .frame(height: 260)
                    .listRowInsets(EdgeInsets())
            } footer: {
                Text("Straight lines between checkpoints; distances are approximate.")
            }

            Section {
                LabeledContent("Covered", value: UnitConverter.displayString(progress.distanceKm, type: .distance, pref: pref))
                LabeledContent("Total", value: UnitConverter.displayString(progress.journey.totalKm, type: .distance, pref: pref))
                if let next = progress.next {
                    LabeledContent("Next stop", value: "\(next.name), \(UnitConverter.displayString(progress.kmToNext, type: .distance, pref: pref))")
                }
                if let started = profile?.journeyStartedAt {
                    LabeledContent("Started", value: started.formatted(date: .abbreviated, time: .omitted))
                }
            } footer: {
                Text("Every walk and run you log since starting moves you along.")
            }

            Section("Checkpoints") {
                ForEach(progress.journey.checkpoints) { checkpoint in
                    let reached = progress.reached.contains(checkpoint)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(reached ? Color.ffSuccess : Color.ffInkMuted)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(checkpoint.name)
                                    .ffFont(.bodyStrong)
                                    .foregroundStyle(Color.ffInk)
                                Spacer()
                                Text(UnitConverter.displayString(checkpoint.cumulativeKm, type: .distance, pref: pref))
                                    .ffFont(.caption)
                                    .foregroundStyle(Color.ffInkMuted)
                            }
                            // Facts unlock as you reach each stop.
                            Text(reached ? checkpoint.fact : "Reach this stop to unlock a fun fact.")
                                .ffFont(.caption)
                                .foregroundStyle(Color.ffInkMuted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(reached ? "Reached" : "Not reached yet")
                }
            }
        }
    }
}

/// The route as straight lines between checkpoints, the stops, and a marker for "you are here".
struct JourneyMap: View {
    let progress: JourneyProgress

    private var coordinates: [CLLocationCoordinate2D] {
        progress.journey.checkpoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            MapPolyline(coordinates: coordinates)
                .stroke(Color.ffAccent2, lineWidth: 4)
            ForEach(progress.journey.checkpoints) { checkpoint in
                let reached = progress.reached.contains(checkpoint)
                Annotation(checkpoint.name, coordinate: CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)) {
                    Circle()
                        .fill(reached ? Color.ffAccent : Color.ffSurface)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.ffLine, lineWidth: 2))
                }
                .annotationTitles(.hidden)
            }
            if let here = progress.position {
                Marker("You", systemImage: "figure.walk", coordinate: CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude))
                    .tint(Color.ffAccent2)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .accessibilityLabel("Map of the \(progress.journey.name) with your position")
    }
}

// MARK: - Picker

struct JourneyPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var pendingJourney: Journey?

    private var activeID: String { profiles.first?.activeJourneyID ?? "" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(JourneyCatalog.all) { journey in
                        Button {
                            if journey.id == activeID { dismiss() } else if activeID.isEmpty { start(journey) } else { pendingJourney = journey }
                        } label: {
                            HStack(spacing: 12) {
                                Text(journey.emoji).font(.title2).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(journey.name).ffFont(.headline).foregroundStyle(Color.ffInk)
                                    Text(journey.blurb).ffFont(.caption).foregroundStyle(Color.ffInkMuted)
                                    Text("\(Int((journey.totalKm / JourneyCatalog.kmPerMile).rounded())) mi · \(journey.checkpoints.count) stops")
                                        .ffFont(.caption)
                                        .foregroundStyle(Color.ffInkMuted)
                                }
                                Spacer()
                                if journey.id == activeID {
                                    Image(systemName: "checkmark").foregroundStyle(Color.ffSuccess)
                                }
                            }
                        }
                        .accessibilityAddTraits(journey.id == activeID ? .isSelected : [])
                    }
                } footer: {
                    Text("Your progress starts at zero and counts every walk and run you log from now on.")
                }

                if !activeID.isEmpty {
                    Section {
                        Button("End Journey", role: .destructive) {
                            guard let profile = profiles.first else { return }
                            profile.activeJourneyID = ""
                            profile.journeyStartedAt = nil
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Choose a Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Switch journeys?",
                isPresented: Binding(get: { pendingJourney != nil }, set: { if !$0 { pendingJourney = nil } }),
                titleVisibility: .visible,
                presenting: pendingJourney
            ) { journey in
                Button("Start \(journey.name)") { start(journey) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Your current journey's progress will reset. Your logged activities aren't affected.")
            }
        }
    }

    private func start(_ journey: Journey) {
        // Onboarding always creates the profile; never make a second one (it would sync).
        guard let profile = profiles.first else { return dismiss() }
        profile.activeJourneyID = journey.id
        profile.journeyStartedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Checkpoint celebration (3.2)

/// One "you reached…" moment. Identifiable so it can drive a full-screen cover.
struct CheckpointMoment: Identifiable, Equatable {
    let journeyName: String
    let checkpoint: Checkpoint
    let isFinish: Bool
    /// "1 of 2" when several were passed at once.
    let position: Int
    let count: Int

    var id: String { "\(journeyName)#\(checkpoint.id)" }
}

/// The Celebration look on the yellow ground: badge pop, the stop, its fun fact. (Celebration.md)
struct JourneyCheckpointView: View {
    let moment: CheckpointMoment
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.ffBg.ignoresSafeArea()

            VStack(spacing: FFSpace.s6) {
                Spacer(minLength: 0)

                if moment.count > 1 {
                    Text("\(moment.position) of \(moment.count)")
                        .ffFont(.label)
                        .foregroundStyle(Color.ffInkMuted)
                }

                VStack(spacing: FFSpace.s4) {
                    FFTag(text: "Journey · \(moment.journeyName)", fill: .ffTypeDistance, foreground: .ffOnTypeDistance)

                    Text(moment.isFinish ? "🏁" : "📍")
                        .font(.system(size: 56))
                        .frame(width: 96, height: 96)
                        .background(Color.ffSurfaceAlt, in: .circle)
                        .overlay(Circle().strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                        .accessibilityHidden(true)

                    Text(moment.isFinish ? "Journey complete!" : "You reached \(moment.checkpoint.name)!")
                        .ffFont(.display)
                        .foregroundStyle(Color.ffInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if moment.isFinish {
                        Text(moment.checkpoint.name)
                            .ffFont(.headline)
                            .foregroundStyle(Color.ffInk)
                    }

                    Text(moment.checkpoint.fact)
                        .ffFont(.body)
                        .foregroundStyle(Color.ffInkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .ffCard()
                .opacity(appeared || reduceMotion ? 1 : 0)

                Spacer(minLength: 0)

                Button("Keep Going", action: onContinue)
                    .buttonStyle(.ffPrimary)
                    .accessibilityIdentifier("checkpointKeepGoing")
            }
            .padding(.horizontal, FFSpace.s5)
            .padding(.bottom, FFSpace.s6)
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
            }
        }
    }
}

#Preview("Checkpoint") {
    JourneyCheckpointView(
        moment: CheckpointMoment(
            journeyName: "Texas Triangle",
            checkpoint: Checkpoint(name: "San Antonio, TX", cumulativeKm: 128, latitude: 29.4, longitude: -98.5,
                                   fact: "Remember the Alamo! It stands a few blocks from the River Walk."),
            isFinish: false, position: 1, count: 1
        ),
        onContinue: {}
    )
}

#Preview("Picker") {
    JourneyPickerSheet()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

#Preview("Map") {
    if let journey = JourneyCatalog.journey(id: "appalachian-trail") {
        JourneyMap(progress: JourneyEngine.progress(journey: journey, distanceKm: 1_200))
            .frame(height: 300)
    }
}
