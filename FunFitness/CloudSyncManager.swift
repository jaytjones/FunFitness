//
//  CloudSyncManager.swift
//  FunFitness
//
//  Observes iCloud account availability and SwiftData/CloudKit sync activity so the Profile
//  screen can show an honest sync status (v2.1). Sync itself is handled automatically by
//  SwiftData via NSPersistentCloudKitContainer — this type only reports on it.
//

import Foundation
import SwiftUI
import CloudKit
import CoreData

@MainActor
@Observable
final class CloudSyncManager {

    enum AccountState {
        case unknown        // still checking, or CloudKit couldn't determine status
        case available      // signed into iCloud; syncing
        case unavailable    // no iCloud account signed in
        case restricted     // iCloud restricted (e.g. parental controls / MDM)
        case syncDisabled   // user turned sync off in-app
    }

    enum SyncState: Equatable {
        case idle
        case syncing
        case upToDate
        case error(String)
    }

    var accountState: AccountState = .unknown
    var syncState: SyncState = .idle
    var lastSyncDate: Date?

    // Written only on the main actor; read once in the nonisolated deinit for cleanup.
    // @ObservationIgnored keeps the @Observable macro from wrapping it so the isolation
    // annotation applies to the real stored property.
    @ObservationIgnored nonisolated(unsafe) private var observer: NSObjectProtocol?

    init() {
        observeSyncEvents()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// The user-facing sync opt-out, persisted in UserDefaults. Reading/writing goes through
    /// PersistenceController so the value and the key stay in one place. A change only takes
    /// effect at the next launch (the container is built once at startup).
    var isSyncEnabledSetting: Bool {
        get { PersistenceController.isSyncEnabled }
        set { UserDefaults.standard.set(newValue, forKey: PersistenceController.syncEnabledDefaultsKey) }
    }

    /// Queries the current iCloud account status for the app's CloudKit container.
    func refreshAccountStatus() async {
        guard PersistenceController.isSyncEnabled else {
            accountState = .syncDisabled
            return
        }
        do {
            let status = try await CKContainer(identifier: PersistenceController.cloudKitContainerID)
                .accountStatus()
            switch status {
            case .available:                            accountState = .available
            case .restricted:                           accountState = .restricted
            case .noAccount:                            accountState = .unavailable
            case .couldNotDetermine, .temporarilyUnavailable:
                                                        accountState = .unknown
            @unknown default:                           accountState = .unknown
            }
        } catch {
            accountState = .unknown
        }
    }

    // MARK: - Sync event observation

    private func observeSyncEvents() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
            else { return }
            // The queue is .main, so it's safe to assume main-actor isolation here.
            MainActor.assumeIsolated {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            syncState = .syncing
        } else if let error = event.error {
            syncState = .error(error.localizedDescription)
        } else {
            syncState = .upToDate
            lastSyncDate = event.endDate
        }
    }
}

// MARK: - Profile section

/// The "iCloud Sync" card shown in ProfileView. Owns its own CloudSyncManager and reads the
/// sync opt-out flag directly, so it's fully self-contained.
struct CloudSyncSection: View {
    @State private var syncManager = CloudSyncManager()
    @State private var showRestartNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("iCloud Sync")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                NotificationToggleRow(
                    title: "Sync to iCloud",
                    subtitle: "Keep your history on all your devices",
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: Color(hex: "#0284C7"),
                    isOn: Binding(
                        get: { syncManager.isSyncEnabledSetting },
                        set: { newValue in
                            syncManager.isSyncEnabledSetting = newValue
                            showRestartNote = true
                        }
                    )
                )
                Divider()
                statusRow
            }
            .background(Color.appCard)
            .clipShape(.rect(cornerRadius: 20))

            if showRestartNote {
                Text("Reopen FunFitness to apply this change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .task {
            await syncManager.refreshAccountStatus()
        }
    }

    private var statusRow: some View {
        HStack {
            Image(systemName: "icloud.fill")
                .foregroundStyle(Color(hex: "#A78BFA"))
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Status")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if syncManager.syncState == .syncing {
                SwiftUI.ProgressView()
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iCloud sync status")
        .accessibilityValue(statusText)
    }

    private var statusText: String {
        switch syncManager.accountState {
        case .syncDisabled: return "Off — your data stays on this device only"
        case .unavailable:  return "Sign in to iCloud in Settings to sync your data"
        case .restricted:   return "iCloud is restricted on this device"
        case .unknown:      return "Checking iCloud…"
        case .available:
            switch syncManager.syncState {
            case .syncing:
                return "Syncing…"
            case .error(let message):
                return "Sync issue: \(message)"
            case .upToDate, .idle:
                if let date = syncManager.lastSyncDate {
                    return "On — last synced \(date.formatted(date: .abbreviated, time: .shortened))"
                }
                return "On"
            }
        }
    }
}
