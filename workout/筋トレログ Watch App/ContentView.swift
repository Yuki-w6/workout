import SwiftUI
import SwiftData
import WorkoutShared

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @State private var didWarmUpCloudKitSync = false

    init() {
        let predicate = #Predicate<Exercise> { $0.isArchived == false }
        let sortDescriptors: [SortDescriptor<Exercise>] = [
            SortDescriptor(\.presetSortKey, order: .forward),
            SortDescriptor(\.bodyPartRaw, order: .forward),
            SortDescriptor(\.name, order: .forward)
        ]
        _exercises = Query(filter: predicate, sort: sortDescriptors)
    }

    // 部位ごとにまとめる。BodyPart.allCasesの並び順をセクション表示順にする。
    // presetSortKey優先のクエリ結果でも、部位でグルーピングすれば同部位内は
    // プリセット→ユーザー作成の順のまま自然にまとまる。
    private var exercisesByBodyPart: [(bodyPart: BodyPart, exercises: [Exercise])] {
        let grouped = Dictionary(grouping: exercises, by: \.bodyPart)
        return BodyPart.allCases.compactMap { bodyPart in
            guard let group = grouped[bodyPart], !group.isEmpty else { return nil }
            return (bodyPart, group)
        }
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
                    List {
                        ForEach(exercisesByBodyPart, id: \.bodyPart) { group in
                            Section(group.bodyPart.displayName) {
                                ForEach(group.exercises) { exercise in
                                    NavigationLink(exercise.name) {
                                        RecordInputView(exercise: exercise)
                                            .id(exercise.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("筋トレログ")
        }
        .onAppear {
            warmUpCloudKitSyncIfNeeded()
        }
    }

    // RecordHeader/RecordSetをCloudKitへ初めて同期する際の遅延初期化コストが、
    // 記録操作のたびに(特にセッション最初の種目で)乗ってしまうことが実機計測で判明した。
    // 空のsave()では効果が無かった(実際の書き込みが発生しないと初期化が走らないため)ので、
    // ダミーのRecordHeader/RecordSetを実際に作成・保存し、直後に削除することで
    // このコストをアプリ起動直後(ユーザーが種目を選ぶより前)に前倒しする。
    private func warmUpCloudKitSyncIfNeeded() {
        guard !didWarmUpCloudKitSync, let exercise = exercises.first else { return }
        didWarmUpCloudKitSync = true

        let header = RecordHeader(date: .distantPast, exercise: exercise)
        modelContext.insert(header)
        let dummySet = RecordSet(
            setNumber: 0,
            weight: 0,
            weightUnit: exercise.defaultWeightUnit,
            repetitions: 0,
            header: header
        )
        modelContext.insert(dummySet)
        header.sets = [dummySet]

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            return
        }

        // modelContext.save()はローカルへの同期書き込みが終わればすぐ返るが、
        // CloudKitへの実際のネットワーク送信はバックグラウンドで非同期に行われる。
        // 即座に削除すると送信が完了する前に消してしまい、CloudKit側の初期化
        // (初回同期のコスト)が前倒しされない可能性があるため、数秒待ってから消す。
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            modelContext.delete(dummySet)
            modelContext.delete(header)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
            }
        }
    }
}
