//
//  GRDBDemoApp.swift
//  GRDBDemo
//
//  Created by David Reed on 4/2/23.
//

import SwiftUI

@main
struct GRDBAsyncDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().environment(\.appDatabase, .shared)
        }
    }
}

// MARK: - Give SwiftUI access to the database
//
// Define a new environment key that grants access to an AppDatabase.
//
// The technique is documented at
// <https://developer.apple.com/documentation/swiftui/environmentkey>.

private struct AppDatabaseKey: EnvironmentKey {
    static var defaultValue: AppDatabase { .empty() }
}

extension EnvironmentValues {
    var appDatabase: AppDatabase {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}
