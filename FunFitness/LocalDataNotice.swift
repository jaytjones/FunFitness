//
//  LocalDataNotice.swift
//  FunFitness
//
//  A gentle Home notice for people whose data lives only on this device (iCloud Sync off, not
//  signed in to iCloud, or iCloud restricted): it isn't backed up, so deleting the app or losing
//  the phone loses it. Points them to iCloud or to Export. "Not now" hides it for 30 days.
//  (Jay, 2026-11-15)
//

import SwiftUI
import SwiftData

/// When the notice shows. Pure so it's unit-tested.
enum LocalDataRule {
    static let snoozeDays = 30

    /// Data stays on this device only in these account states. Still checking → don't nag.
    static func isLocalOnly(_ state: CloudSyncManager.AccountState) -> Bool {
        switch state {
        case .syncDisabled, .unavailable, .restricted: return true
        case .available, .unknown: return false
        }
    }

    static func shouldShow(state: CloudSyncManager.AccountState, activityCount: Int, dismissedAt: Date?, now: Date) -> Bool {
        guard isLocalOnly(state), activityCount > 0 else { return false }
        guard let dismissedAt else { return true }
        return now.timeIntervalSince(dismissedAt) >= Double(snoozeDays) * 24 * 3600
    }
}

/// The owner (Home) checks the iCloud account and passes it in: a hidden view's own `.task`
/// wouldn't run, so the notice couldn't check for itself.
struct LocalDataNotice: View {
    let pref: UnitPreference
    let accountState: CloudSyncManager.AccountState

    @Query private var activities: [ActivityLog]
    /// When "Not now" was tapped (seconds since 1970; 0 = never).
    @AppStorage("localDataNoticeDismissedAt") private var dismissedAt: Double = 0
    @State private var exportURL: URL?
    @State private var turnedOnSync = false

    private var dismissedDate: Date? { dismissedAt > 0 ? Date(timeIntervalSince1970: dismissedAt) : nil }

    var body: some View {
        if LocalDataRule.shouldShow(state: accountState, activityCount: activities.count,
                                    dismissedAt: dismissedDate, now: Date()) {
            card
        }
    }

    private var reason: LocalizedStringKey {
        switch accountState {
        case .syncDisabled:
            return "iCloud Sync is off, so they aren't backed up. If you delete the app or lose your phone, they're gone."
        case .restricted:
            return "iCloud isn't available on this device, so they aren't backed up. Export a copy to keep them safe."
        default:
            return "You're not signed in to iCloud, so they aren't backed up. Sign in to iCloud in the Settings app, or export a copy."
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: FFSpace.s3) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "icloud.slash.fill")
                    .foregroundStyle(Color.ffLink)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your workouts are only on this iPhone")
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffInk)
                    Text(reason)
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if turnedOnSync {
                        Text("Reopen FunFitness to finish turning on iCloud Sync.")
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffSuccess)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: FFSpace.s4) { actions }
                VStack(alignment: .leading, spacing: FFSpace.s2) { actions }
            }
            .ffFont(.bodyStrong)
            .foregroundStyle(Color.ffLink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("localDataNotice")
        .task(id: activities.count) {
            exportURL = ExportManager.csvFileURL(activities: activities, pref: pref)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if accountState == .syncDisabled && !turnedOnSync {
            Button("Turn On iCloud Sync") {
                // Takes effect at the next launch (the store is opened once at startup).
                UserDefaults.standard.set(true, forKey: PersistenceController.syncEnabledDefaultsKey)
                turnedOnSync = true
            }
            .accessibilityIdentifier("localDataTurnOnSync")
        }
        if let exportURL {
            ShareLink(item: exportURL) {
                Text("Export a Copy")
            }
            .accessibilityIdentifier("localDataExport")
        }
        Button("Not Now") {
            dismissedAt = Date().timeIntervalSince1970
        }
        .foregroundStyle(Color.ffInkMuted)
        .accessibilityIdentifier("localDataNotNow")
    }
}
