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
    init() {
        // Draw in the Style the app is showing (3.3).
        StyleRuntime.loadFromAppGroup()
        #if INTERNAL_STYLES
        ArcadeFonts.register()
        #endif
    }

    var body: some Widget {
        FunFitnessWidget()
        WorkoutLiveActivityWidget()   // 3.1 tracked walk/run Live Activity
    }
}
