import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let exerciseRepository: ExerciseRepository

    private init() {
        let seed = [
            Exercise(name: "Bench Press", bodyPart: .chest),
            Exercise(name: "Deadlift", bodyPart: .back),
            Exercise(name: "Squat", bodyPart: .legs)
        ]
        self.exerciseRepository = InMemoryExerciseRepository(initialExercises: seed)
    }
}
