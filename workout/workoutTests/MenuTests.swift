import SwiftData
import Testing
@testable import workout

struct MenuTests {
    @Test func createMenu() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Bench Press", bodyPart: .chest)
        context.insert(exercise)
        let menu = Menu(name: "Push Day", exercises: [exercise])
        context.insert(menu)
        try context.save()

        let menus = try context.fetch(FetchDescriptor<Menu>())
        #expect(menus.count == 1)
    }

    @Test func readMenu() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Shoulder Press", bodyPart: .shoulders)
        context.insert(exercise)
        let menu = Menu(name: "Upper Body", exercises: [exercise])
        context.insert(menu)
        try context.save()

        let fetched = try context.fetch(
            FetchDescriptor<Menu>(predicate: #Predicate { $0.id == menu.id })
        )
        #expect(fetched.first?.exercises.count == 1)
    }

    @Test func updateMenu() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Lunge", bodyPart: .legs)
        context.insert(exercise)
        let menu = Menu(name: "Leg Day", exercises: [exercise])
        context.insert(menu)
        try context.save()

        menu.name = "Lower Body Day"
        try context.save()

        let fetched = try context.fetch(
            FetchDescriptor<Menu>(predicate: #Predicate { $0.id == menu.id })
        )
        #expect(fetched.first?.name == "Lower Body Day")
    }

    @Test func deleteMenu() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Row", bodyPart: .back)
        context.insert(exercise)
        let menu = Menu(name: "Pull Day", exercises: [exercise])
        context.insert(menu)
        try context.save()

        context.delete(menu)
        try context.save()

        let menus = try context.fetch(FetchDescriptor<Menu>())
        #expect(menus.isEmpty)
    }
}
