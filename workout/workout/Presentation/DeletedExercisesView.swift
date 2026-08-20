import SwiftUI

/// 削除(アーカイブ)した種目を戻すための画面。
/// 削除は論理削除なのでデータは残っているが、これまで復元する導線が無く
/// 一度消すとアプリ内で戻す手段が無かった。
struct DeletedExercisesView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @Binding var isPresented: Bool
    @State private var archived: [Exercise] = []

    var body: some View {
        NavigationStack {
            Group {
                if archived.isEmpty {
                    VStack(spacing: 8) {
                        Text("削除した種目はありません")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(archived, id: \.id) { exercise in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    Text(exercise.bodyPart.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("戻す") {
                                    viewModel.restoreExercise(id: exercise.id)
                                    reload()
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .navigationTitle("削除した種目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        archived = viewModel.archivedExercises()
    }
}
