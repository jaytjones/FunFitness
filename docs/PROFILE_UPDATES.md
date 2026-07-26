# Profile Updates - FunFitness

## New Features Added

### ✅ 1. Height Field with Unit Hint

**Change:** Height field now shows "in" (inches) hint, matching the weight field's "lbs" hint.

**Implementation:**
- Converted height field from text input to numeric input using `EditableNumberRow`
- Shows unit "in" next to the number during editing
- Displays as "72 in" when not editing
- Still stores as string in database for backwards compatibility
- Parses any existing height values that might have mixed formatting

**User Experience:**
- **Display mode:** "72 in" or "Not set"
- **Edit mode:** TextField shows "72" with "in" label next to it
- User types only numbers, unit is always separate

---

### ✅ 2. Clear Activity Data

**Change:** New option in Settings section to clear all activity logs and achievements.

**Implementation:**
- Added "Clear Activity Data" row with orange trash icon
- Confirmation alert warns user the action cannot be undone
- Deletes all `ActivityLog` entries
- Deletes all `UnlockedAchievement` entries
- Resets ViewModel totals to zero
- **Preserves** profile information (name, email, fitness goal, avatar, etc.)

**Alert Message:**
> "This will delete all your logged activities and achievements. Your profile information will be kept. This action cannot be undone."

**Use Case:**
- User wants to start fresh with tracking but keep their profile
- Testing/debugging during development

---

### ✅ 3. Clear All Data

**Change:** New option in Settings section to completely reset the app.

**Implementation:**
- Added "Clear All Data" row with red warning triangle icon
- Confirmation alert warns user the action cannot be undone
- Deletes all `ActivityLog` entries
- Deletes all `UnlockedAchievement` entries
- Deletes `UserProfile` entry
- After clearing, app will show onboarding screen again
- Resets ViewModel state

**Alert Message:**
> "This will delete your profile, all activities, and all achievements. You'll need to set up your account again. This action cannot be undone."

**Use Case:**
- User wants to completely reset the app
- Switch to a different user account
- Testing/debugging during development

---

## Settings Section Order (Updated)

The Settings section now shows options in this order:

1. **Clear Activity Data** (orange trash icon) - Destructive action
2. **Clear All Data** (red warning icon) - Destructive action
3. **Notifications** (purple bell icon) - Navigation link (V2)
4. **Privacy & Security** (purple lock icon) - Navigation link (V2)

The destructive actions are placed at the top to make them easily accessible for users who need them, while being visually distinct with warning colors.

---

## Technical Details

### New Components

**SettingsActionRow**
```swift
struct SettingsActionRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
}
```
- Similar to `SettingsRow` but executes an action instead of navigating
- Accepts custom icon color for visual distinction
- No chevron icon (not a navigation)

### New State Variables

```swift
@State private var showingClearActivityAlert = false
@State private var showingClearAllDataAlert = false
```

### New Functions

**clearActivityData()**
- Deletes all activities and achievements
- Resets ViewModel totals
- Saves SwiftData context
- Does NOT delete profile

**clearAllData()**
- Calls `clearActivityData()` first
- Then deletes the profile
- Saves SwiftData context
- Returns user to onboarding

---

## Files Modified

1. **ProfileView.swift**
   - Added 2 new state variables for alerts
   - Added 2 new alert handlers
   - Added 2 new clearing functions
   - Added new `SettingsActionRow` component
   - Updated height field to use `EditableNumberRow` with "in" unit
   - Updated Settings section layout

---

## Visual Design

### Icon Colors
- **Clear Activity Data:** Orange (#EA580C) - Warning level
- **Clear All Data:** Red (#E11D48) - Danger level
- **Regular Settings:** Purple (#5B21B6) - Standard level

### Alert Style
- Both use `.alert()` modifier with destructive button style
- "Cancel" button is default (not destructive)
- Action button is red and marked as destructive role

---

## Testing Recommendations

1. **Test Height Field:**
   - Tap pencil icon
   - Enter "72" 
   - Verify displays as "72 in"
   - Edit again, should show "72" in field with "in" label next to it

2. **Test Clear Activity Data:**
   - Log some activities and unlock achievements
   - Tap "Clear Activity Data"
   - Confirm in alert
   - Verify: 
     - All activities deleted
     - All achievements deleted
     - Profile still exists
     - Stats show 0/0/0

3. **Test Clear All Data:**
   - Set up profile with activities
   - Tap "Clear All Data"
   - Confirm in alert
   - Verify:
     - Returned to onboarding screen
     - All data wiped
     - Can create new profile

---

**All features implemented and ready for testing! ✅**
