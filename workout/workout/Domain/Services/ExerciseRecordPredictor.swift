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

    func predict(records: [RecordHeader], unit: WeightUnit, maxSetNumber: Int) -> [Int: ExerciseRecordPrediction] {
        var weightSamples: [Int: [Double]] = [:]
        var repsSamples: [Int: [Double]] = [:]
        var weightDeltas: [Double] = []
        var repsDeltas: [Double] = []

        let sortedRecords = records.sorted { $0.date < $1.date }
        for record in sortedRecords {
            let details = record.details.sorted { $0.setNumber < $1.setNumber }
                .filter { $0.weightUnit == unit }
            for detail in details {
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
                        bucket.append(Double(detail.repetitions))
                        repsSamples[detail.setNumber] = bucket
                    }
                }
            }

            if details.count >= 2 {
                for index in 0..<(details.count - 1) {
                    let current = details[index]
                    let next = details[index + 1]
                    if current.weight > 0, next.weight > 0 {
                        weightDeltas.append(next.weight - current.weight)
                    }
                    if current.repetitions > 0, next.repetitions > 0 {
                        repsDeltas.append(Double(next.repetitions - current.repetitions))
                    }
                }
            }
        }

        let averageWeightDelta = average(of: weightDeltas)
        let averageRepsDelta = average(of: repsDeltas)
        var predictions: [Int: ExerciseRecordPrediction] = [:]
        var predictedWeights: [Int: Double] = [:]
        var predictedReps: [Int: Double] = [:]

        if maxSetNumber > 0 {
            for setNumber in 1...maxSetNumber {
                if let predictedWeight = trendAdjustedValue(samples: weightSamples[setNumber] ?? []) {
                    predictedWeights[setNumber] = predictedWeight
                } else if let previous = predictedWeights[setNumber - 1], let delta = averageWeightDelta {
                    predictedWeights[setNumber] = previous + delta
                }

                if let predictedRepsValue = trendAdjustedValue(samples: repsSamples[setNumber] ?? []) {
                    predictedReps[setNumber] = predictedRepsValue
                } else if let previous = predictedReps[setNumber - 1], let delta = averageRepsDelta {
                    predictedReps[setNumber] = previous + delta
                }

                let weight = predictedWeights[setNumber].flatMap { $0 > 0 ? $0 : nil }
                let reps = predictedReps[setNumber].flatMap { $0 > 0 ? Int(round($0)) : nil }
                if weight != nil || reps != nil {
                    predictions[setNumber] = ExerciseRecordPrediction(
                        setNumber: setNumber,
                        weight: weight,
                        reps: reps
                    )
                }
            }
        }
        return predictions
    }
}

private extension ExerciseRecordPredictor {
    func trendAdjustedValue(samples: [Double]) -> Double? {
        guard !samples.isEmpty else {
            return nil
        }
        let averageValue = samples.reduce(0, +) / Double(samples.count)
        guard samples.count >= 2 else {
            return averageValue
        }
        let deltas = zip(samples, samples.dropFirst()).map { $0 - $1 }
        let trend = deltas.reduce(0, +) / Double(deltas.count)
        return averageValue + trend
    }

    func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }
}
