import SwiftUI
import SwiftData
import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

@main
struct workoutApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var ads = AdsInitializer()
    @AppStorage("cloudSyncEnabled") private var isCloudSyncEnabled = true
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    
    init() {
        let appColor = UIColor(red: 0.992, green: 0.294, blue: 0.004, alpha: 1.0)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance.selected.iconColor = appColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: appColor]
        appearance.inlineLayoutAppearance.selected.iconColor = appColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: appColor]
        appearance.compactInlineLayoutAppearance.selected.iconColor = appColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: appColor]

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = appState.container {
                    let repository = container.exerciseRepository
                    let viewModel = ExerciseListViewModel(
                        fetchExercises: FetchExercisesUseCase(repository: repository),
                        fetchExercise: FetchExerciseUseCase(repository: repository),
                        addExercise: AddExerciseUseCase(repository: repository),
                        updateExercise: UpdateExerciseUseCase(repository: repository),
                        deleteExercise: DeleteExerciseUseCase(repository: repository)
                    )
                    ZStack(alignment: .top) {
                        ContentView(viewModel: viewModel, isCloudSyncEnabled: $isCloudSyncEnabled)
                            .modelContainer(container.modelContainer)
                            .disabled(appState.isImporting)

                        if let warningMessage = appState.warningMessage {
                            HStack(spacing: 12) {
                                Text(warningMessage)
                                    .font(.footnote.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                Button {
                                    appState.warningMessage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 6)
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                        if appState.isImporting {
                            ZStack {
                                Color.black.opacity(0.2)
                                    .ignoresSafeArea()
                                SyncSkeletonView(title: statusMessage)
                            }
                        }
                    }
                } else if let errorMessage = appState.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        if let cloudKitStatusMessage = appState.cloudKitStatusMessage {
                            Text(cloudKitStatusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        Button("再試行") {
                            Task { await appState.loadContainer(useCloud: isCloudSyncEnabled) }
                        }
                    }
                } else {
                    ProgressView("読み込み中...")
                }
            }
            .task {
                #if DEBUG
                // Xcode Preview 判定（環境変数）
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    await appState.loadContainer(useCloud: isCloudSyncEnabled)
                    return
                }
                #endif

                await MainActor.run {
                    ads.startIfNeeded()
                }
                await appState.loadContainer(useCloud: isCloudSyncEnabled)
            }
            .onChange(of: isCloudSyncEnabled) { _, newValue in
                Task { await appState.loadContainer(useCloud: newValue) }
            }
        }
    }

    private var statusMessage: String {
        if appState.isImporting {
            return "引き継ぎ中..."
        }
        return "初期化中..."
    }
}

private struct SyncSkeletonView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .frame(height: 18)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .frame(height: 18)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .frame(height: 18)
            }
            .redacted(reason: .placeholder)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .frame(height: 120)
                .redacted(reason: .placeholder)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
    }
}

@MainActor
private final class AppState: ObservableObject {
    @Published var container: AppContainer?
    @Published var errorMessage: String?
    @Published var cloudKitStatusMessage: String?
    @Published var warningMessage: String?
    @Published var isImporting = false
    @Published var isCloudAvailable = false

    func loadContainer(useCloud: Bool) async {
        errorMessage = nil
        do {
            let result = try await AppContainer.make(useCloud: useCloud)
            self.container = result.container
            warningMessage = result.warningMessage
            isCloudAvailable = useCloud
        } catch {
            self.container = nil
            warningMessage = nil
            let detail = (error as NSError).localizedDescription
            let nsError = error as NSError
#if DEBUG
            print("ModelContainer error:", nsError.domain, nsError.code, nsError.userInfo)
#endif
            errorMessage = "データの初期化に失敗しました。\n\(detail)\n再起動しても改善しない場合はお問い合わせください。"
        }
    }

}
