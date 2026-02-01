import Foundation

enum PresetExerciseDefinitions {
    static let all: [PresetExerciseDefinition] = [
        PresetExerciseDefinition(
            id: UUID(uuidString: "0a8a5dec-e7f9-405b-bd0e-9f4454b1c328")!,
            seedKey: "bench_press",
            seedVersion: 1,
            name: "ベンチプレス",
            bodyPart: .chest,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "6f88c12e-a399-4b31-a9d9-c32f00733869")!,
            seedKey: "chest_press",
            seedVersion: 1,
            name: "チェストプレス",
            bodyPart: .chest,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "349b02d5-6175-40ff-9255-d94ce4d3b2e4")!,
            seedKey: "deadlift",
            seedVersion: 1,
            name: "デットリフト",
            bodyPart: .back,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "345e4884-d945-4a3d-9e2f-c4fa9bb7d4af")!,
            seedKey: "lat_pulldown",
            seedVersion: 1,
            name: "ラットプルダウン",
            bodyPart: .back,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "ad40d7e3-eb1a-41d1-8125-967ddea0cd8d")!,
            seedKey: "squat",
            seedVersion: 1,
            name: "スクワット",
            bodyPart: .legs,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "7a38c212-9e21-4e48-bff7-04d975ae85f0")!,
            seedKey: "leg_press",
            seedVersion: 1,
            name: "レッグプレス",
            bodyPart: .legs,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "24bb8a64-78ba-470a-92a6-e59bf6e5d43f")!,
            seedKey: "shoulder_press",
            seedVersion: 1,
            name: "ショルダープレス",
            bodyPart: .shoulders,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "80ab552d-e762-46ec-a80e-f40752ee5379")!,
            seedKey: "side_raise",
            seedVersion: 1,
            name: "サイドレイズ",
            bodyPart: .shoulders,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "51e28625-96aa-4c42-9b33-c2fe202e087b")!,
            seedKey: "rear_raise",
            seedVersion: 1,
            name: "リアレイズ",
            bodyPart: .shoulders,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "ff395e31-a501-4d1b-9a72-663a3dad04ad")!,
            seedKey: "arm_curl",
            seedVersion: 1,
            name: "アームカール",
            bodyPart: .arms,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "c4db904c-5e15-407c-8ee2-0f44603caf8e")!,
            seedKey: "hip_thrust",
            seedVersion: 1,
            name: "ヒップスラスト",
            bodyPart: .glutes,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "8244380e-0c68-4464-ad40-e45312d19c16")!,
            seedKey: "abdominal",
            seedVersion: 1,
            name: "アブドミナル",
            bodyPart: .core,
            defaultWeightUnit: .kg
        )
    ]
}
