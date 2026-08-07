//
//  UserProfile.swift
//  FunFitness
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var email: String
    var dateOfBirth: Date?
    // age kept for migration compatibility; use computedAge going forward
    var age: Int?
    // heightInches retained (column originally named "heightFeet") for migration;
    // new entries write to heightCm only
    @Attribute(originalName: "heightFeet") var heightInches: String?
    var heightCm: Double?
    // Column was "weightLbs" before v1.2; now stores kg. Migration converts on first launch.
    @Attribute(originalName: "weightLbs") var weightKg: Double?
    var fitnessGoal: String
    // UnitPreference.rawValue — defaults to "imperial"
    var unitPreference: String
    // Weekly goals stored in SI: km and kg
    var weeklyDistanceGoal: Double?
    var weeklyWeightGoal: Double?
    @Attribute(.externalStorage) var avatarImageData: Data?
    var activeTheme: String
    var createdAt: Date

    // MARK: - Notification preferences (all default off; user opts in)
    var notifyStreakAtRisk: Bool
    var notifyMilestoneNudge: Bool
    var notifyWeeklyRecap: Bool
    var notifyComparisonOfDay: Bool

    // MARK: - HealthKit preferences (v1.4; default off, user opts in)
    // Auto-import distance workouts from Apple Health.
    var healthKitImportEnabled: Bool = false
    // Write manually logged distance activities back to Apple Health.
    var healthKitWriteBackEnabled: Bool = false

    init(
        id: UUID = UUID(),
        name: String = "",
        email: String = "",
        dateOfBirth: Date? = nil,
        age: Int? = nil,
        heightInches: String? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        fitnessGoal: String = "Stay Active",
        unitPreference: String = UnitPreference.imperial.rawValue,
        weeklyDistanceGoal: Double? = nil,
        weeklyWeightGoal: Double? = nil,
        avatarImageData: Data? = nil,
        activeTheme: String = "animals",
        createdAt: Date = Date(),
        notifyStreakAtRisk: Bool = false,
        notifyMilestoneNudge: Bool = false,
        notifyWeeklyRecap: Bool = false,
        notifyComparisonOfDay: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.age = age
        self.heightInches = heightInches
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.fitnessGoal = fitnessGoal
        self.unitPreference = unitPreference
        self.weeklyDistanceGoal = weeklyDistanceGoal
        self.weeklyWeightGoal = weeklyWeightGoal
        self.avatarImageData = avatarImageData
        self.activeTheme = activeTheme
        self.createdAt = createdAt
        self.notifyStreakAtRisk = notifyStreakAtRisk
        self.notifyMilestoneNudge = notifyMilestoneNudge
        self.notifyWeeklyRecap = notifyWeeklyRecap
        self.notifyComparisonOfDay = notifyComparisonOfDay
    }

    var unitPref: UnitPreference {
        UnitPreference(rawValue: unitPreference) ?? .imperial
    }

    // Age derived from dateOfBirth; falls back to the stored age field.
    var computedAge: Int? {
        if let dob = dateOfBirth {
            return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
        }
        return age
    }
}
