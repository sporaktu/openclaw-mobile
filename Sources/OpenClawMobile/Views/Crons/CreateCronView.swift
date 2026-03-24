import SwiftUI

struct CreateCronView: View {
    @Environment(CronService.self) private var cronService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var scheduleKind = "every"
    @State private var cronExpression = ""
    @State private var selectedInterval = 3_600_000 // 1h default
    @State private var payloadKind = "agentTurn"
    @State private var message = ""
    @State private var enabled = true
    @State private var isSaving = false

    private let intervals: [(String, Int)] = [
        ("5 minutes", 300_000),
        ("15 minutes", 900_000),
        ("30 minutes", 1_800_000),
        ("1 hour", 3_600_000),
        ("6 hours", 21_600_000),
        ("12 hours", 43_200_000),
        ("24 hours", 86_400_000),
    ]

    private var isValid: Bool {
        !name.isEmpty && !message.isEmpty &&
        (scheduleKind == "every" || !cronExpression.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Toggle("Enabled", isOn: $enabled)
                }

                Section("Schedule") {
                    Picker("Kind", selection: $scheduleKind) {
                        Text("Every").tag("every")
                        Text("Cron Expression").tag("cron")
                    }
                    .pickerStyle(.segmented)

                    if scheduleKind == "every" {
                        Picker("Interval", selection: $selectedInterval) {
                            ForEach(intervals, id: \.1) { label, ms in
                                Text(label).tag(ms)
                            }
                        }
                    } else {
                        TextField("Cron Expression (e.g. 0 * * * *)", text: $cronExpression)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Payload") {
                    Picker("Kind", selection: $payloadKind) {
                        Text("Agent Turn").tag("agentTurn")
                        Text("System Event").tag("systemEvent")
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading) {
                        Text("Message")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                        TextEditor(text: $message)
                            .frame(minHeight: 80)
                            .font(AppTheme.bodyFont)
                    }
                }
            }
            .navigationTitle("New Cron Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let payload = CreateCronPayload(
            name: name,
            scheduleKind: scheduleKind,
            schedule: scheduleKind == "cron" ? cronExpression : nil,
            everyMs: scheduleKind == "every" ? selectedInterval : nil,
            payloadKind: payloadKind,
            message: message,
            model: nil,
            enabled: enabled
        )
        Task {
            try? await cronService.createJob(payload)
            dismiss()
        }
    }
}

#Preview {
    CreateCronView()
        .environment(CronService())
}
