import SwiftUI
import SwiftData
import UIKit
import FirebaseCore
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        return true
    }
}

@main
struct workoutApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        let pink = UIColor(red: 0.992, green: 0.294, blue: 0.004, alpha: 1.0)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance.selected.iconColor = pink
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: pink]
        appearance.inlineLayoutAppearance.selected.iconColor = pink
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: pink]
        appearance.compactInlineLayoutAppearance.selected.iconColor = pink
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: pink]

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            if let container = appState.container {
                let repository = container.exerciseRepository
                let viewModel = ExerciseListViewModel(
                    fetchExercises: FetchExercisesUseCase(repository: repository),
                    fetchExercise: FetchExerciseUseCase(repository: repository),
                    addExercise: AddExerciseUseCase(repository: repository),
                    updateExercise: UpdateExerciseUseCase(repository: repository),
                    updateExerciseRecord: UpdateExerciseRecordUseCase(repository: repository),
                    deleteExercise: DeleteExerciseUseCase(repository: repository)
                )
                ZStack(alignment: .top) {
                    ContentView(viewModel: viewModel)
                        .modelContainer(container.modelContainer)

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
                        Task { await appState.loadContainer() }
                    }
                }
            } else {
                ProgressView("読み込み中...")
            }
        }
    }
}

@MainActor
private final class AppState: ObservableObject {
    @Published var container: AppContainer?
    @Published var errorMessage: String?
    @Published var cloudKitStatusMessage: String?
    @Published var warningMessage: String?

    init() {
        Task { await loadContainer() }
    }

    func loadContainer() async {
        await updateCloudKitStatus()
        errorMessage = nil
        do {
            let result = try AppContainer.make()
            self.container = result.container
            warningMessage = result.warningMessage
        } catch {
            self.container = nil
            warningMessage = nil
            let detail = (error as NSError).localizedDescription
            let nsError = error as NSError
            print("ModelContainer error:", nsError.domain, nsError.code, nsError.userInfo)
            errorMessage = "データの初期化に失敗しました。\n\(detail)\n再起動しても改善しない場合はお問い合わせください。"
        }
    }

    private func updateCloudKitStatus() async {
        do {
            let status = try await CKContainer(identifier: "iCloud.com.mayamayk.workoutlog").accountStatus()
            switch status {
            case .available:
                cloudKitStatusMessage = nil
            case .noAccount:
                cloudKitStatusMessage = "iCloudにサインインしてください。"
            case .restricted:
                cloudKitStatusMessage = "iCloudが制限されています。スクリーンタイム等をご確認ください。"
            case .couldNotDetermine:
                cloudKitStatusMessage = "iCloudの状態を確認できませんでした。"
            case .temporarilyUnavailable:
                cloudKitStatusMessage = "iCloudが一時的に利用できません。"
            @unknown default:
                cloudKitStatusMessage = "iCloudの状態を確認できませんでした。"
            }
        } catch {
            cloudKitStatusMessage = "iCloudの状態取得に失敗しました。"
        }
    }
}
