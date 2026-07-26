//
//  UserProfile.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var email: String
    var age: Int?
    // Stores height in inches as a numeric string; @Attribute maps from the old "heightFeet" column name
    @Attribute(originalName: "heightFeet") var heightInches: String?
    var weightLbs: Double?
    var fitnessGoal: String
    @Attribute(.externalStorage) var avatarImageData: Data?
    var activeTheme: String // "animals" | "cities" | "landmarks"
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        email: String = "",
        age: Int? = nil,
        heightInches: String? = nil,
        weightLbs: Double? = nil,
        fitnessGoal: String = "Stay Active",
        avatarImageData: Data? = nil,
        activeTheme: String = "animals",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.age = age
        self.heightInches = heightInches
        self.weightLbs = weightLbs
        self.fitnessGoal = fitnessGoal
        self.avatarImageData = avatarImageData
        self.activeTheme = activeTheme
        self.createdAt = createdAt
    }
}
