//
//  FunFitnessApp.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData
#if INTERNAL_SOCIAL
import CloudKit
#endif

@main
struct FunFitnessApp: App {
    // Shared CloudKit-backed container (v2.1). Built by PersistenceController so the app and
    // the Siri intent use an identical sync configuration.
    private let sharedModelContainer: ModelContainer
    #if INTERNAL_SOCIAL
    // Friends (3.4, unreleased): receives the silent push when a friend's Friends data changes.
    @UIApplicationDelegateAdaptor(FriendsAppDelegate.self) private var friendsAppDelegate
    #endif

    init() {
        #if INTERNAL_STYLES
        ArcadeFonts.register()   // unreleased Arcade headings (3.3)
        #endif
        #if DEBUG
        // One-off: launch a Debug build on a signed-in device with `-initCloudKitSchema` to push
        // the model layer to the CloudKit Development environment, then deploy it to Production
        // from the CloudKit Console. Runs before the shared container so the two don't open the
        // same store at once. (pre-3.1, plan item B1)
        if ProcessInfo.processInfo.arguments.contains("-initCloudKitSchema") {
            do {
                try PersistenceController.initializeCloudKitSchemaForDevelopment()
                print("CloudKit schema initialized in the Development environment.")
            } catch {
                print("CloudKit schema initialization failed: \(error)")
            }
        }
        #endif
        #if DEBUG
        if SampleData.isRequested {
            // Screenshots / visual checks: an in-memory store with sample data. (3.2)
            sharedModelContainer = SampleData.makeContainer()
            WatchConnector.shared.activate()
            return
        }
        #endif
        sharedModelContainer = PersistenceController.makeSharedContainer()
        // Early, so entries logged on the Watch are received even on a background launch. (3.1)
        WatchConnector.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

#if INTERNAL_SOCIAL
/// Friends (3.4): turns the shared-database subscription's silent push into "🙌 Sam high-fived
/// you!" notifications (iCloud can't name people in its own alerts). Other pushes, such as
/// SwiftData's iCloud sync, are left to CloudKit.
final class FriendsAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == SocialRecords.subscriptionID else { return .noData }
        let isBackground = application.applicationState != .active
        return await SocialSession.shared.checkForNews(postNotifications: isBackground) ? .newData : .noData
    }
}
#endif
