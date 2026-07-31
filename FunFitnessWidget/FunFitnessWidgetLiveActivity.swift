//
//  FunFitnessWidgetLiveActivity.swift
//  FunFitnessWidget
//
//  Created by Jay Jones on 7/31/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FunFitnessWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FunFitnessWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FunFitnessWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FunFitnessWidgetAttributes {
    fileprivate static var preview: FunFitnessWidgetAttributes {
        FunFitnessWidgetAttributes(name: "World")
    }
}

extension FunFitnessWidgetAttributes.ContentState {
    fileprivate static var smiley: FunFitnessWidgetAttributes.ContentState {
        FunFitnessWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FunFitnessWidgetAttributes.ContentState {
         FunFitnessWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FunFitnessWidgetAttributes.preview) {
   FunFitnessWidgetLiveActivity()
} contentStates: {
    FunFitnessWidgetAttributes.ContentState.smiley
    FunFitnessWidgetAttributes.ContentState.starEyes
}
