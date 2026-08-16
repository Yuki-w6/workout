import SwiftUI
import SwiftData
import WorkoutShared

struct ContentView: View {
    @Query private var exercises: [Exercise]

    init() {
        let predicate = #Predicate<Exercise> { $0.isArchived == false }
        let sortDescriptors: [SortDescriptor<Exercise>] = [
            SortDescriptor(\.presetSortKey, order: .forward),
            SortDescriptor(\.bodyPartRaw, order: .forward),
            SortDescriptor(\.name, order: .forward)
        ]
        _exercises = Query(filter: predicate, sort: sortDescriptors)
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "種目がありません",
                        systemImage: "arrow.triangle.2.circlepath.icloud",
                        description: Text("iPhoneアプリを開いてiCloud同期を待ってください")
                    )
                } else {
                    List(exercises) { exercise in
                        NavigationLink(exercise.name) {
                            RecordInputView(exercise: exercise)
                        }
                    }
                }
            }
            .navigationTitle("筋トレログ")
        }
    }
}
