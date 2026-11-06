//
//  NowTrackingBar.swift
//  FunFitness
//
//  A pinned "now tracking" bar above the tab bar while a GPS walk/run or a strength session is
//  running, on every tab, like the Music mini-player (TestFlight FB-0003). Tapping it reopens the
//  tracker or the session screen. iOS 26.1+ uses the tab bar's bottom accessory (which shrinks
//  inline when the tab bar minimizes); earlier versions pin the same bar with `safeAreaInset`.
//

import SwiftUI

// MARK: - Content

/// What the bar says. Pure, so it's unit-tested without the shared tracker or session.
struct NowTrackingContent: Equatable {
    enum Destination: Equatable { case tracker, strength }

    let destination: Destination
    let systemImage: String
    /// "Walk", "Run paused", "Strength".
    let title: String
    /// "1.2 mi · 18:42", "3 sets · Rest 0:45".
    let detail: String
    /// Live (pulsing icon) vs. paused or waiting for review.
    let isLive: Bool

    /// A walk/run comes first; the app doesn't allow both at once. Nil when nothing is running.
    static func make(
        trackerPhase: WorkoutTracker.Phase,
        kindName: String,
        distanceKm: Double,
        movingSeconds: TimeInterval,
        strengthPhase: StrengthSessionManager.Phase,
        setCount: Int,
        restRemaining: TimeInterval,
        strengthSeconds: TimeInterval,
        pref: UnitPreference
    ) -> NowTrackingContent? {
        let distance = UnitConverter.distanceString(distanceKm, pref: pref)
        let moving = UnitConverter.elapsedString(movingSeconds)
        switch trackerPhase {
        case .active:
            return NowTrackingContent(destination: .tracker, systemImage: "location.fill",
                                      title: kindName, detail: "\(distance) · \(moving)", isLive: true)
        case .paused:
            return NowTrackingContent(destination: .tracker, systemImage: "pause.circle.fill",
                                      title: "\(kindName) paused", detail: "\(distance) · \(moving)", isLive: false)
        case .finished:
            return NowTrackingContent(destination: .tracker, systemImage: "checkmark.circle.fill",
                                      title: "\(kindName) finished", detail: "Tap to review and save", isLive: false)
        case .idle:
            break
        }

        let sets = "\(setCount) set\(setCount == 1 ? "" : "s")"
        switch strengthPhase {
        case .active:
            let detail = restRemaining > 0
                ? "\(sets) · Rest \(UnitConverter.elapsedString(restRemaining))"
                : "\(sets) · \(UnitConverter.elapsedString(strengthSeconds))"
            return NowTrackingContent(destination: .strength, systemImage: restRemaining > 0 ? "timer" : "dumbbell.fill",
                                      title: "Strength", detail: detail, isLive: true)
        case .finished:
            return NowTrackingContent(destination: .strength, systemImage: "checkmark.circle.fill",
                                      title: "Strength session done", detail: "Tap to see your summary", isLive: false)
        case .idle:
            return nil
        }
    }

    /// The bar's content right now, from the shared tracker and strength session.
    @MainActor
    static func current(at date: Date, pref: UnitPreference) -> NowTrackingContent? {
        let tracker = WorkoutTracker.shared
        let strength = StrengthSessionManager.shared
        return make(
            trackerPhase: tracker.phase,
            kindName: tracker.kind.displayName,
            distanceKm: tracker.distanceMeters / 1000,
            movingSeconds: tracker.movingSeconds(at: date),
            strengthPhase: strength.phase,
            setCount: strength.session?.setCount ?? 0,
            restRemaining: strength.session?.restRemaining(at: date) ?? 0,
            strengthSeconds: strength.elapsedSeconds(at: date),
            pref: pref
        )
    }

    /// Whether the bar should show. Read in a view body so it updates as phases change.
    @MainActor
    static var isShowing: Bool {
        WorkoutTracker.shared.phase != .idle || StrengthSessionManager.shared.phase != .idle
    }
}

// MARK: - Bar

struct NowTrackingBar: View {
    enum Style { case accessory, inset }

    let viewModel: AppViewModel
    let style: Style

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let content = NowTrackingContent.current(at: context.date, pref: viewModel.unitPreference) {
                Button {
                    open(content.destination)
                } label: {
                    // Full row above the tab bar; just the icon and detail when the accessory is inline.
                    ViewThatFits(in: .horizontal) {
                        NowTrackingRow(content: content, style: style, showsTitle: true)
                        NowTrackingRow(content: content, style: style, showsTitle: false)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(content.title). \(content.detail)")
                .accessibilityHint(content.destination == .tracker ? "Opens the tracker" : "Opens the strength session")
                .accessibilityIdentifier("nowTrackingBar")
            }
        }
    }

    private func open(_ destination: NowTrackingContent.Destination) {
        switch destination {
        case .tracker:  viewModel.showTracker = true
        case .strength: viewModel.showStrengthSession = true
        }
    }
}

// MARK: - Row

struct NowTrackingRow: View {
    let content: NowTrackingContent
    let style: NowTrackingBar.Style
    var showsTitle = true

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: content.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ffLink)
                .symbolEffect(.pulse, isActive: content.isLive)
                .accessibilityHidden(true)
            if showsTitle {
                Text(content.title)
                    .ffFont(.bodyStrong)
                    .foregroundStyle(Color.ffInk)
                    .lineLimit(1)
            }
            Text(content.detail)
                .ffFont(.body)
                .foregroundStyle(Color.ffInkMuted)
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.ffInkMuted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, style == .inset ? 12 : 0)
        .frame(maxWidth: .infinity, maxHeight: style == .accessory ? .infinity : nil)
        .background {
            // The tab bar accessory brings its own glass; the fallback needs a background.
            if style == .inset {
                Capsule().fill(Color.ffSurface)
                    .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
                    .background(Capsule().fill(Color.ffShadowInk).offset(x: FFShadow.press, y: FFShadow.press))
            }
        }
        .contentShape(.rect)
    }
}

// MARK: - Placement

extension View {
    /// On the TabView: the bar as the tab bar's bottom accessory (iOS 26.1+).
    func nowTrackingAccessory(viewModel: AppViewModel, isShowing: Bool) -> some View {
        modifier(NowTrackingAccessoryModifier(viewModel: viewModel, isShowing: isShowing))
    }

    /// On each tab's content: the bar pinned above the tab bar on iOS before 26.1.
    func nowTrackingInset(viewModel: AppViewModel, isShowing: Bool) -> some View {
        modifier(NowTrackingInsetModifier(viewModel: viewModel, isShowing: isShowing))
    }
}

private struct NowTrackingAccessoryModifier: ViewModifier {
    let viewModel: AppViewModel
    let isShowing: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isShowing) {
                NowTrackingBar(viewModel: viewModel, style: .accessory)
            }
        } else {
            content
        }
    }
}

private struct NowTrackingInsetModifier: ViewModifier {
    let viewModel: AppViewModel
    let isShowing: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content
        } else {
            content.safeAreaInset(edge: .bottom) {
                if isShowing {
                    NowTrackingBar(viewModel: viewModel, style: .inset)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - Previews

private let previewStrength = NowTrackingContent(
    destination: .strength, systemImage: "timer", title: "Strength", detail: "3 sets · Rest 0:45", isLive: true
)
private let previewWalk = NowTrackingContent(
    destination: .tracker, systemImage: "location.fill", title: "Walk", detail: "1.2 mi · 18:42", isLive: true
)

@available(iOS 26.1, *)
private struct NowTrackingAccessoryPreview: View {
    let content: NowTrackingContent

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { Color.ffBg.ignoresSafeArea() }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") { Color.ffBg.ignoresSafeArea() }
            Tab("Achievements", systemImage: "trophy") { Color.ffBg.ignoresSafeArea() }
            Tab("Profile", systemImage: "person.circle") { Color.ffBg.ignoresSafeArea() }
        }
        .tint(Color.ffLink)
        .tabViewBottomAccessory(isEnabled: true) {
            NowTrackingRow(content: content, style: .accessory)
        }
    }
}

#Preview("Accessory · strength") {
    if #available(iOS 26.1, *) { NowTrackingAccessoryPreview(content: previewStrength) }
}

#Preview("Accessory · walk") {
    if #available(iOS 26.1, *) { NowTrackingAccessoryPreview(content: previewWalk) }
}

#Preview("Inset fallback") {
    ZStack(alignment: .bottom) {
        Color.ffBg.ignoresSafeArea()
        NowTrackingRow(content: previewStrength, style: .inset)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }
}
