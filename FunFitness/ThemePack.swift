//
//  ThemePack.swift
//  FunFitness
//
//  Themes as data (v2.2). Previously the active theme was a fixed `Theme` enum; now each pack
//  is a value in a catalog, so new packs are added as data (Segment 4: Food + Dinosaurs) and
//  3.3 can gate/purchase them via the `isPremium` hook without touching an enum. Pack `id`s are
//  stable strings that match the values persisted in `UserProfile.activeTheme`, so no migration
//  is needed for the original three packs.
//

import Foundation

struct ThemePack: Identifiable, Equatable, Hashable {
    let id: String            // stable identifier, also persisted in UserProfile.activeTheme
    let displayName: String
    let iconEmoji: String
    /// Reserved for 3.3 StoreKit gating. All packs are free (false) in 2.2.
    let isPremium: Bool
    let sortOrder: Int
}

enum ThemePackCatalog {
    static let animals   = ThemePack(id: "animals",   displayName: "Animals",   iconEmoji: "🦒", isPremium: false, sortOrder: 0)
    static let cities    = ThemePack(id: "cities",    displayName: "Cities",    iconEmoji: "🏙",  isPremium: false, sortOrder: 1)
    static let landmarks = ThemePack(id: "landmarks", displayName: "Landmarks", iconEmoji: "🗼", isPremium: false, sortOrder: 2)

    /// All packs, in display order.
    static let all: [ThemePack] = [animals, cities, landmarks]

    static let byId: [String: ThemePack] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// The pack for a stored id, falling back to the default if unknown.
    static func pack(id: String) -> ThemePack { byId[id] ?? animals }

    static let `default` = animals
}
