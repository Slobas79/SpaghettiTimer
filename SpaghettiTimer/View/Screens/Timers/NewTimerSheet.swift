//
//  NewTimerSheet.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI

struct NewTimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var isPinned: Bool

    let editing: TimerPreset?
    let onSave: (String, TimeInterval, Bool) -> Void

    init(editing: TimerPreset? = nil, onSave: @escaping (String, TimeInterval, Bool) -> Void) {
        self.editing = editing
        self.onSave = onSave
        let total = Int((editing?.duration ?? 300).rounded())
        _name = State(initialValue: editing?.name ?? "")
        _hours = State(initialValue: total / 3600)
        _minutes = State(initialValue: (total % 3600) / 60)
        _seconds = State(initialValue: total % 60)
        _isPinned = State(initialValue: editing != nil)
    }

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    private var canSave: Bool {
        duration > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Tea", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Duration") {
                    HStack(spacing: 0) {
                        wheel(value: $hours, range: 0...23, label: "h")
                        wheel(value: $minutes, range: 0...59, label: "m")
                        wheel(value: $seconds, range: 0...59, label: "s")
                    }
                    .frame(maxHeight: 160)
                }
                if editing == nil {
                    Section {
                        Toggle(isOn: $isPinned) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pin timer")
                                    Text("Keep this timer permanently available.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: isPinned ? "pin.fill" : "pin")
                            }
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "New Timer" : "Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing != nil ? "Save" : (isPinned ? "Save" : "Start")) {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), duration, isPinned)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private func wheel(value: Binding<Int>, range: ClosedRange<Int>, label: String) -> some View {
        HStack(spacing: 4) {
            Picker(label, selection: value) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
