//
//  NewTimerSheet.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI

struct NewTimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0
    @State private var isPinned: Bool = false
    @State private var autoRestart: Bool = false
    @State private var restartMinutes: Int = 0
    @State private var restartSeconds: Int = 30

    let onSave: (String, TimeInterval, Bool, TimeInterval?) -> Void

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    private var restartDelay: TimeInterval? {
        guard autoRestart else { return nil }
        let total = TimeInterval(restartMinutes * 60 + restartSeconds)
        return total > 0 ? total : nil
    }

    private var canSave: Bool {
        duration > 0 && (!autoRestart || (restartMinutes * 60 + restartSeconds) > 0)
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
                Section("Auto-restart") {
                    Toggle(isOn: $autoRestart) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-restart after finish")
                                Text("Re-run this timer automatically after a cooldown delay.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    if autoRestart {
                        HStack(spacing: 0) {
                            wheel(value: $restartMinutes, range: 0...59, label: "m")
                            wheel(value: $restartSeconds, range: 0...59, label: "s")
                        }
                        .frame(maxHeight: 140)
                    }
                }
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
            .navigationTitle("New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPinned ? "Save" : "Start") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), duration, isPinned, restartDelay)
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
