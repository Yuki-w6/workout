import SwiftUI
import SwiftData
import UIKit

@main
struct workoutApp: App {
    @StateObject private var appState = AppState()
    
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
                ContentView(viewModel: viewModel)
                    .modelContainer(container.modelContainer)
            } else {
                ProgressView("読み込み中...")
            }
        }
    }
}

@MainActor
private final class AppState: ObservableObject {
    @Published var container: AppContainer?

    init() {
        Task.detached(priority: .userInitiated) {
            do {
                let container = try AppContainer.make()
                await MainActor.run {
                    self.container = container
                }
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }
}
