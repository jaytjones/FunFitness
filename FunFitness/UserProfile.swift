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
    var heightFeet: String?
    var weightLbs: Double?
    var fitnessGoal: String
    var avatarImageData: Data?
    var activeTheme: String // "animals" | "cities" | "landmarks"
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String = "",
        email: String = "",
        age: Int? = nil,
        heightFeet: String? = nil,
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
        self.heightFeet = heightFeet
        self.weightLbs = weightLbs
        self.fitnessGoal = fitnessGoal
        self.avatarImageData = avatarImageData
        self.activeTheme = activeTheme
        self.createdAt = createdAt
    }
}
