import SwiftData
@testable import workout

func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([
        Exercise.self,
        Menu.self,
        RecordHeader.self,
        RecordDetail.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}
