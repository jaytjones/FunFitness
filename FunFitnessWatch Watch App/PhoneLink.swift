//
//  PhoneLink.swift
//  FunFitnessWatch Watch App
//
//  The Watch end of the iPhone link (3.1): sends logged entries to the phone (queued, so they
//  arrive even when the phone app isn't open) and keeps the exercise list and units the phone
//  last sent. Message types live in WatchShared/WatchMessages.swift.
//

import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class PhoneLink: NSObject {
    static let shared = PhoneLink()

    /// The latest context from the phone, cached so the app works before the phone answers.
    private(set) var context: WatchContext?
    /// Entries sent this session that are still waiting for the phone.
    private(set) var queuedCount = 0

    private static let contextKey = "phoneContext"

    private override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: Self.contextKey) {
            context = try? JSONDecoder().decode(WatchContext.self, from: data)
        }
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var usesMetric: Bool { context?.usesMetric ?? false }

    func exercises(for kind: WatchQuickLog.Kind) -> [WatchExercise] {
        (context?.exercises ?? []).filter { $0.kind == kind }
    }

    func send(_ log: WatchQuickLog) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(log.encoded())
        queuedCount = WCSession.default.outstandingUserInfoTransfers.count
    }

    fileprivate func store(_ context: WatchContext) {
        self.context = context
        if let data = try? JSONEncoder().encode(context) {
            UserDefaults.standard.set(data, forKey: Self.contextKey)
        }
    }

    fileprivate func refreshQueue() {
        queuedCount = WCSession.default.outstandingUserInfoTransfers.count
    }
}

extension PhoneLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard let context = WatchContext.decode(session.receivedApplicationContext) else { return }
        Task { @MainActor in PhoneLink.shared.store(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let context = WatchContext.decode(applicationContext) else { return }
        Task { @MainActor in PhoneLink.shared.store(context) }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in PhoneLink.shared.refreshQueue() }
    }
}
