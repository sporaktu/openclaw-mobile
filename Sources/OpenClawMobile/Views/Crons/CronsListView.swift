import SwiftUI

struct CronsListView: View {
    @Environment(CronService.self) private var cronService
    @State private var showingCreate = false
    @State private var jobToDelete: CronJob?

    var body: some View {
        NavigationStack {
            Group {
                if cronService.isLoading && cronService.jobs.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if cronService.jobs.isEmpty {
                    ContentUnavailableView(
                        "No Cron Jobs",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Tap + to create a scheduled job.")
                    )
                } else {
                    List {
                        ForEach(cronService.jobs) { job in
                            NavigationLink(value: job) {
                                CronRow(job: job)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    jobToDelete = job
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    Task {
                                        try? await cronService.toggleJob(id: job.id, enabled: !job.enabled)
                                    }
                                } label: {
                                    Label(
                                        job.enabled ? "Disable" : "Enable",
                                        systemImage: job.enabled ? "pause.circle" : "play.circle"
                                    )
                                }
                                .tint(job.enabled ? AppTheme.statusPending : AppTheme.statusCompleted)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cron Jobs")
            .navigationDestination(for: CronJob.self) { job in
                CronDetailView(job: job)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await cronService.fetchJobs()
            }
            .sheet(isPresented: $showingCreate) {
                CreateCronView()
            }
            .confirmationDialog(
                "Delete Cron Job",
                isPresented: Binding(
                    get: { jobToDelete != nil },
                    set: { if !$0 { jobToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let job = jobToDelete {
                        Task { try? await cronService.deleteJob(id: job.id) }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .task {
                await cronService.fetchJobs()
            }
        }
    }
}

#Preview {
    CronsListView()
        .environment(CronService())
}
