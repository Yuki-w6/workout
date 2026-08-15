//
//  ______App.swift
//  筋トレログ Watch App
//
//  Created by 間山友喜 on 2026/08/15.
//

import SwiftUI
import SwiftData

@main
struct _______Watch_AppApp: App {
    private let modelContainer: ModelContainer?
    private let modelContainerError: String?

    init() {
        do {
            modelContainer = try WatchModelContainer.make()
            modelContainerError = nil
        } catch {
            modelContainer = nil
            modelContainerError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .modelContainer(modelContainer)
            } else {
                Text("データベースの初期化に失敗しました\n\(modelContainerError ?? "")")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}
