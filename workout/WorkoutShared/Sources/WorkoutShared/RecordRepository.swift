import Foundation
import SwiftData

public protocol RecordRepository {
    func fetchHeaders(for exerciseID: UUID) throws -> [RecordHeader]
    func fetchHeaders(from: Date, to: Date) throws -> [RecordHeader]
}

public final class SwiftDataRecordRepository: RecordRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchHeaders(for exerciseID: UUID) throws -> [RecordHeader] {
        let desc = FetchDescriptor<RecordHeader>(
            predicate: #Predicate { $0.exerciseIDSnapshot == exerciseID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(desc)
    }

    public func fetchHeaders(from: Date, to: Date) throws -> [RecordHeader] {
        let desc = FetchDescriptor<RecordHeader>(
            predicate: #Predicate { $0.date >= from && $0.date < to },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(desc)
    }
}
