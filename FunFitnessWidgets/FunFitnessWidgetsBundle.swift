//
//  FunFitnessWidgetsBundle.swift
//  FunFitnessWidgets
//
//  Created by Jay Jones on 10/10/26.
//

import WidgetKit
import SwiftUI

@main
struct FunFitnessWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FunFitnessWidget()
        WorkoutLiveActivityWidget()   // 3.1 tracked walk/run Live Activity
    }
}
