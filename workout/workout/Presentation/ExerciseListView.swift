import SwiftUI

struct ExerciseListView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @State private var searchText = ""

    private let bodyPartSections: [(bodyPart: BodyPart, title: String)] = [
        (.chest, "胸"),
        (.back, "背中"),
        (.legs, "脚"),
        (.shoulders, "肩"),
        (.arms, "腕"),
        (.glutes, "お尻"),
        (.core, "お腹")
    ]

    private var filteredExercises: [Exercise] {
        guard !searchText.isEmpty else {
            return viewModel.exercises
        }
        return viewModel.exercises.filter { exercise in
            exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func exercises(for bodyPart: BodyPart) -> [Exercise] {
        filteredExercises.filter { $0.bodyPart == bodyPart }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(bodyPartSections, id: \.bodyPart) { section in
                    let sectionExercises = exercises(for: section.bodyPart)
                    Section(section.title) {
                        ForEach(sectionExercises, id: \.id) { exercise in
                            NavigationLink {
                                ExerciseDetailView(
                                    viewModel: viewModel,
                                    exerciseID: exercise.id,
                                    isNewRecord: true,
                                    initialDate: nil
                                )
                            } label: {
                                Text(exercise.name)
                                    .font(.headline)
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.compactMap { index in
                                sectionExercises.indices.contains(index) ? sectionExercises[index].id : nil
                            }
                            viewModel.deleteExercises(ids: ids)
                        }

                        Button {
                            viewModel.addExercise(bodyPart: section.bodyPart)
                        } label: {
                            Label("種目を追加", systemImage: "plus")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "種目を検索"
            )
            .onAppear {
                viewModel.load()
            }
        }
    }
}
