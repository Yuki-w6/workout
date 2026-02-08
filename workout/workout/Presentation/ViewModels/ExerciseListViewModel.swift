import Foundation

@MainActor
final class ExerciseListViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []

    private let fetchExercises: FetchExercisesUseCase
    private let fetchExerciseUseCase: FetchExerciseUseCase
    private let addExercise: AddExerciseUseCase
    private let updateExerciseUseCase: UpdateExerciseUseCase
    private let deleteExerciseUseCase: DeleteExerciseUseCase

    init(
        fetchExercises: FetchExercisesUseCase,
        fetchExercise: FetchExerciseUseCase,
        addExercise: AddExerciseUseCase,
        updateExercise: UpdateExerciseUseCase,
        deleteExercise: DeleteExerciseUseCase
    ) {
        self.fetchExercises = fetchExercises
        self.fetchExerciseUseCase = fetchExercise
        self.addExercise = addExercise
        self.updateExerciseUseCase = updateExercise
        self.deleteExerciseUseCase = deleteExercise
    }

    func load() {
        exercises = dedupeByID(fetchExercises.execute())
    }

    func exercises(matching searchText: String) -> [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    func availablePresets(matching searchText: String) -> [PresetExerciseDefinition] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingPresetIDs = Set(exercises.filter { $0.isPreset }.map { $0.id })
        let existingSeedKeys = Set(exercises.compactMap { $0.seedKey })
        return PresetExerciseDefinitions.all.filter { preset in
            guard existingPresetIDs.contains(preset.id) == false else { return false }
            guard existingSeedKeys.contains(preset.seedKey) == false else { return false }
            guard !trimmed.isEmpty else { return true }
            return preset.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func ensureExercise(for preset: PresetExerciseDefinition) -> Exercise? {
        if let existingByID = exercises.first(where: { $0.id == preset.id }) {
            return existingByID
        }
        if let existingBySeed = exercises.first(where: { $0.seedKey == preset.seedKey }) {
            return existingBySeed
        }
        let created = addExercise.executePreset(preset)
        load()
        return created
    }

    func exercise(id: UUID) -> Exercise? {
        fetchExerciseUseCase.execute(id: id)
    }

    func addExercise(name: String, bodyPart: BodyPart) {
        _ = addExercise.execute(name: name, bodyPart: bodyPart)
        load()
    }

    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) {
        _ = updateExerciseUseCase.execute(id: id, name: name, bodyPart: bodyPart)
        load()
    }

    func deleteExercises(at offsets: IndexSet) -> [UUID] {
        let ids = offsets.compactMap { index in
            exercises.indices.contains(index) ? exercises[index].id : nil
        }
        return deleteExercises(ids: ids)
    }

    func deleteExercises(ids: [UUID]) -> [UUID] {
        var failedIds: [UUID] = []
        for id in ids {
            let deleted = deleteExerciseUseCase.execute(id: id)
            if !deleted {
                failedIds.append(id)
            }
        }
        load()
        return failedIds
    }

    private func dedupeByID(_ items: [Exercise]) -> [Exercise] {
        var seen: Set<UUID> = []
        var result: [Exercise] = []
        result.reserveCapacity(items.count)
        for item in items {
            if seen.insert(item.id).inserted {
                result.append(item)
            }
        }
        return result
    }
}
