import Foundation

struct ExerciseRecordPrediction {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
}

struct ExerciseRecordPredictor {
    let maxSamplesPerSet: Int

    init(maxSamplesPerSet: Int = 3) {
        self.maxSamplesPerSet = maxSamplesPerSet
    }

    func predict(records: [RecordHeader], unit: WeightUnit) -> [Int: ExerciseRecordPrediction] {
        var weightSamples: [Int: [Double]] = [:]
        var repsSamples: [Int: [Int]] = [:]

        for record in records {
            let details = record.details.sorted { $0.setNumber < $1.setNumber }
            for detail in details where detail.weightUnit == unit {
                if detail.weight > 0 {
                    var bucket = weightSamples[detail.setNumber, default: []]
                    if bucket.count < maxSamplesPerSet {
                        bucket.append(detail.weight)
                        weightSamples[detail.setNumber] = bucket
                    }
                }
                if detail.repetitions > 0 {
                    var bucket = repsSamples[detail.setNumber, default: []]
                    if bucket.count < maxSamplesPerSet {
                        bucket.append(detail.repetitions)
                        repsSamples[detail.setNumber] = bucket
                    }
                }
            }
        }

        let setNumbers = Set(weightSamples.keys).union(repsSamples.keys)
        var predictions: [Int: ExerciseRecordPrediction] = [:]
        for setNumber in setNumbers {
            let weights = weightSamples[setNumber] ?? []
            let reps = repsSamples[setNumber] ?? []
            let weightAverage = weights.isEmpty ? nil : (weights.reduce(0, +) / Double(weights.count))
            let repsAverage = reps.isEmpty ? nil : Int(round(Double(reps.reduce(0, +)) / Double(reps.count)))
            predictions[setNumber] = ExerciseRecordPrediction(
                setNumber: setNumber,
                weight: weightAverage,
                reps: repsAverage
            )
        }
        return predictions
    }
}
