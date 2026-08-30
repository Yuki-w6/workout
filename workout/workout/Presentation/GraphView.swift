import SwiftUI
import SwiftData

/// グラフタブ。部位ごとに種目を並べ、タップでその種目のグラフ画面へ送る。
/// 以前は部位・種目・指標を3つのメニューで選ばせていたが、
/// ホーム画面と同じ「一覧から選ぶ」形に揃えた。
struct GraphView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @Query(sort: \RecordHeader.date) private var records: [RecordHeader]

    private let bodyPartOrder: [BodyPart] = [
        .chest,
        .back,
        .legs,
        .shoulders,
        .arms,
        .glutes,
        .core,
        .fullBody,
        .other
    ]

    var body: some View {
        NavigationStack {
            Group {
                if recordedExercises.isEmpty {
                    ContentUnavailableView(
                        "まだ記録がありません",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("種目を記録するとグラフが表示されます。")
                    )
                } else {
                    listContent
                }
            }
            .navigationTitle("グラフ")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.load()
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(bodyPartOrder, id: \.self) { bodyPart in
                    let exercises = recordedExercises.filter { $0.bodyPart == bodyPart }
                    if !exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(bodyPart.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                    NavigationLink {
                                        ExerciseGraphView(exercise: exercise)
                                    } label: {
                                        HStack {
                                            Text(exercise.name)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if index < exercises.count - 1 {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    /// 記録が1件でもある種目だけを出す。
    /// 未記録の種目を出すと、タップした先が空のグラフになって空振りするため。
    private var recordedExercises: [Exercise] {
        let idsWithRecords = Set(
            records
                .filter { $0.hasRecordedSets }
                .map(\.exerciseIDSnapshot)
        )
        return viewModel.exercises.filter { idsWithRecords.contains($0.id) }
    }
}
