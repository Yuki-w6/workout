import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ExerciseListViewModel
    @AppStorage("hasRequestedTrackingAuthorization") private var hasRequestedTrackingAuthorization = false
    @State private var hasStartedAds = false

    init(viewModel: ExerciseListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        TabView {
            ExerciseListView(viewModel: viewModel)
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "house")
                        Text("ホーム")
                    }
                }
            RecordListView(viewModel: viewModel)
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "calendar")
                        Text("記録")
                    }
                }
            GraphView(viewModel: viewModel)
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("グラフ")
                    }
                }
        }
        .task {
            await MainActor.run {
                requestTrackingAuthorizationIfNeeded()
            }
        }
    }

    private func requestTrackingAuthorizationIfNeeded() {
        guard !hasRequestedTrackingAuthorization else {
            startMobileAdsIfNeeded()
            return
        }
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            guard status == .notDetermined else {
                hasRequestedTrackingAuthorization = true
                startMobileAdsIfNeeded()
                return
            }
            ATTrackingManager.requestTrackingAuthorization { @Sendable _ in
                Task { @MainActor in
                    hasRequestedTrackingAuthorization = true
                    startMobileAdsIfNeeded()
                }
            }
        } else {
            hasRequestedTrackingAuthorization = true
            startMobileAdsIfNeeded()
        }
    }

    private func startMobileAdsIfNeeded() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                startMobileAdsIfNeeded()
            }
            return
        }
        guard !hasStartedAds else { return }
        hasStartedAds = true
        MobileAds.shared.start(completionHandler: { _ in })
    }
}

#Preview {
    let repository = InMemoryExerciseRepository()
    let viewModel = ExerciseListViewModel(
        fetchExercises: FetchExercisesUseCase(repository: repository),
        fetchExercise: FetchExerciseUseCase(repository: repository),
        addExercise: AddExerciseUseCase(repository: repository),
        updateExercise: UpdateExerciseUseCase(repository: repository),
        updateExerciseRecord: UpdateExerciseRecordUseCase(repository: repository),
        deleteExercise: DeleteExerciseUseCase(repository: repository)
    )
    return ContentView(viewModel: viewModel)
}
