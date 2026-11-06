//
//  ExercisePicker.swift
//  FunFitness
//
//  Choosing a named exercise for a Weight/Reps set (3.1, C3): a row that opens a searchable
//  list of the bundled and custom exercises for that type, with "Add your own" at the bottom.
//  Used by the log sheet, the live strength session, and the edit sheet.
//

import SwiftUI
import SwiftData

/// "Exercise   Bench Press ›" — red outline when `showError` (an exercise is required).
struct ExercisePickerRow: View {
    let type: ActivityType
    @Binding var exerciseID: String?
    var showError = false

    @State private var showPicker = false
    private let library = ExerciseLibrary.shared

    private var selected: Exercise? { library.exercise(id: exerciseID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                showPicker = true
            } label: {
                HStack {
                    Text("Exercise")
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffInk)
                    Spacer()
                    Text(selected?.name ?? "Choose")
                        .ffFont(.bodyStrong)
                        .foregroundStyle(selected == nil ? Color.ffLink : Color.ffInk)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.ffInkMuted)
                        .accessibilityHidden(true)
                }
                .padding()
                .ffWell()
                .overlay(
                    RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
                        .strokeBorder(showError ? Color.ffDanger : Color.clear, lineWidth: FFStroke.card)
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exercise")
            .accessibilityValue(selected?.name ?? "None chosen")
            .accessibilityHint("Opens the exercise list")
            .accessibilityIdentifier("exercisePickerRow")

            if showError {
                Text("Choose an exercise")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffDanger)
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet(type: type, selection: $exerciseID)
        }
    }
}

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let type: ActivityType
    @Binding var selection: String?

    @State private var search = ""
    @State private var showAddCustom = false
    private let library = ExerciseLibrary.shared

    private var matches: [Exercise] {
        let all = library.exercises(for: type)
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.muscles.contains { $0.displayName.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(matches) { exercise in
                        Button {
                            selection = exercise.id
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .ffFont(.body)
                                        .foregroundStyle(Color.ffInk)
                                    Text(exercise.muscles.map(\.displayName).joined(separator: ", "))
                                        .ffFont(.caption)
                                        .foregroundStyle(Color.ffInkMuted)
                                }
                                Spacer()
                                if exercise.id == selection {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.ffLink)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(exercise.id == selection ? .isSelected : [])
                        .listRowBackground(Color.ffSurface)
                    }
                } footer: {
                    if matches.isEmpty {
                        Text("No exercises match “\(search)”.")
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffInkMuted)
                    }
                }

                Section {
                    Button {
                        showAddCustom = true
                    } label: {
                        Label("Add Your Own Exercise", systemImage: "plus.circle.fill")
                            .ffFont(.bodyStrong)
                            .foregroundStyle(Color.ffLink)
                    }
                    .accessibilityIdentifier("addCustomExerciseButton")
                    .listRowBackground(Color.ffSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ffBg)
            .searchable(text: $search, prompt: "Search exercises or muscles")
            .navigationTitle(type == .reps ? "Bodyweight Exercise" : "Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomExerciseSheet(type: type, initialName: search) { newID in
                    selection = newID
                    dismiss()
                }
            }
        }
    }
}

struct AddCustomExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let type: ActivityType
    let onAdded: (String) -> Void

    @State private var name: String
    @State private var muscles: Set<MuscleGroup> = []

    init(type: ActivityType, initialName: String = "", onAdded: @escaping (String) -> Void) {
        self.type = type
        self.onAdded = onAdded
        _name = State(initialValue: initialName.trimmingCharacters(in: .whitespaces))
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .ffFont(.body)
                        .foregroundStyle(Color.ffInk)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("customExerciseName")
                        .listRowBackground(Color.ffSurface)
                } footer: {
                    Text(type == .reps ? "A bodyweight move, logged as reps." : "A lift, logged as weight × reps.")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }

                Section {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        Button {
                            if muscles.contains(muscle) { muscles.remove(muscle) } else { muscles.insert(muscle) }
                        } label: {
                            HStack {
                                Text(muscle.displayName).ffFont(.body).foregroundStyle(Color.ffInk)
                                Spacer()
                                if muscles.contains(muscle) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.ffLink)
                                }
                            }
                        }
                        .accessibilityAddTraits(muscles.contains(muscle) ? .isSelected : [])
                        .listRowBackground(Color.ffSurface)
                    }
                } header: {
                    Text("Muscles worked")
                        .ffFont(.label)
                        .foregroundStyle(Color.ffInkMuted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ffBg)
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func add() {
        let ordered = MuscleGroup.allCases.filter(muscles.contains)
        let custom = CustomExercise(name: trimmedName, type: type, muscles: ordered)
        modelContext.insert(custom)
        try? modelContext.save()
        // Update the library now rather than waiting for ContentView's query to notice.
        let all = (try? modelContext.fetch(FetchDescriptor<CustomExercise>())) ?? [custom]
        ExerciseLibrary.shared.setCustom(all)
        onAdded(custom.exercise.id)
        dismiss()
    }
}

#Preview {
    @Previewable @State var id: String? = "bench-press"
    ExercisePickerRow(type: .weight, exerciseID: $id)
        .padding()
        .modelContainer(for: [CustomExercise.self], inMemory: true)
}
