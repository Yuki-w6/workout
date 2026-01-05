import SwiftUI

struct ExerciseListView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @State private var searchText = ""
    @State private var editingExercise: Exercise?
    @State private var draftExerciseName = ""
    @State private var isEditAlertPresented = false
    @State private var addingBodyPart: BodyPart?
    @State private var draftNewExerciseName = ""
    @State private var isAddAlertPresented = false
    @State private var isDeleteBlockedAlertPresented = false

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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    let failedIds = viewModel.deleteExercises(ids: [exercise.id])
                                    if !failedIds.isEmpty {
                                        isDeleteBlockedAlertPresented = true
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                                Button {
                                    editingExercise = exercise
                                    draftExerciseName = exercise.name
                                    isEditAlertPresented = true
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                }
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.compactMap { index in
                                sectionExercises.indices.contains(index) ? sectionExercises[index].id : nil
                            }
                            let failedIds = viewModel.deleteExercises(ids: ids)
                            if !failedIds.isEmpty {
                                isDeleteBlockedAlertPresented = true
                            }
                        }

                        Button {
                            addingBodyPart = section.bodyPart
                            draftNewExerciseName = ""
                            isAddAlertPresented = true
                        } label: {
                            Label("種目を追加", systemImage: "plus")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .tint(.secondary)
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
            .alert("種目名を変更", isPresented: $isEditAlertPresented) {
                TextField("種目名", text: $draftExerciseName)
                Button("保存") {
                    guard let exercise = editingExercise else {
                        return
                    }
                    viewModel.updateExercise(
                        id: exercise.id,
                        name: draftExerciseName,
                        bodyPart: exercise.bodyPart
                    )
                    editingExercise = nil
                }
                Button("キャンセル", role: .cancel) {
                    editingExercise = nil
                }
            } message: {
                Text("新しい種目名を入力してください")
            }
            .alert("削除できません", isPresented: $isDeleteBlockedAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("記録のある種目は削除できません。")
            }
            .alert("種目を追加", isPresented: $isAddAlertPresented) {
                TextField("種目名", text: $draftNewExerciseName)
                Button("追加") {
                    guard let bodyPart = addingBodyPart else {
                        return
                    }
                    let trimmedName = draftNewExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalName = trimmedName.isEmpty ? "新しい種目" : trimmedName
                    viewModel.addExercise(name: finalName, bodyPart: bodyPart)
                    addingBodyPart = nil
                }
                Button("キャンセル", role: .cancel) {
                    addingBodyPart = nil
                }
            } message: {
                Text("種目名を入力してください")
            }
            .onChange(of: isEditAlertPresented) { _, newValue in
                if !newValue {
                    editingExercise = nil
                }
            }
            .onChange(of: isAddAlertPresented) { _, newValue in
                if !newValue {
                    addingBodyPart = nil
                }
            }
        }
    }
}
