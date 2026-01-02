import Foundation

@MainActor
final class ExerciseListViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []

    private let fetchExercises: FetchExercisesUseCase
    private let addExercise: AddExerciseUseCase

    init(fetchExercises: FetchExercisesUseCase, addExercise: AddExerciseUseCase) {
        self.fetchExercises = fetchExercises
        self.addExercise = addExercise
    }

    func load() {
        exercises = fetchExercises.execute()
    }

    func addSampleExercise() {
        let bodyPart = BodyPart.allCases.randomElement() ?? .fullBody
        let exercise = addExercise.execute(name: "New Exercise", bodyPart: bodyPart)
        exercises.append(exercise)
    }
}
