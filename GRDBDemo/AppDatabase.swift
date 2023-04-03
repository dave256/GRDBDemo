//
//  AppDatabase.swift
//  GRDBDemo
//
//  Created by David Reed on 4/2/23.
//

import Foundation
import GRDB

/// AppDatabase lets the application access the database.
///
/// It applies the pratices recommended at
/// <https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md>
struct AppDatabase {
    /// Creates an `AppDatabase`, and make sure the database schema is ready.
    init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    /// Provides access to the database.
    ///
    /// Application can use a `DatabasePool`, while SwiftUI previews and tests
    /// can use a fast in-memory `DatabaseQueue`.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections>
    private let dbWriter: any DatabaseWriter

    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations>
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Speed up development by nuking the database when migrations change
        // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations>
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("createUserPost") { db in
            // Create a table
            // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseschema>
            try db.create(table: "user") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }

            try db.create(table: "post") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("userId", .integer)
                    .notNull()
                    .indexed()
                    .references("user", onDelete: .cascade)
                t.column("content", .text)
            }
        }

        // Migrations for future application versions will be inserted here:
        // migrator.registerMigration(...) { db in
        //     ...
        // }

        return migrator
    }
}

extension AppDatabase {
    /// The database for the application
    static let shared = makeShared()

    private static func makeShared() -> AppDatabase {
        do {
            // Pick a folder for storing the SQLite database, as well as
            // the various temporary files created during normal database
            // operations (https://sqlite.org/tempfiles.html).
            let fileManager = FileManager()
            let folderURL = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("database", isDirectory: true)

            // Support for tests: delete the database if requested
            if CommandLine.arguments.contains("-reset") {
                try? fileManager.removeItem(at: folderURL)
            }

            // Create the database folder if needed
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            // Connect to a database on disk
            // See https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections
            let dbURL = folderURL.appendingPathComponent("db.sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)

            // Create the AppDatabase
            let appDatabase = try AppDatabase(dbPool)

            // Prepare the database with test fixtures if requested
//            if CommandLine.arguments.contains("-fixedTestData") {
//                try appDatabase.createPlayersForUITests()
//            } else {
//                // Otherwise, populate the database if it is empty, for better
//                // demo purpose.
//                try appDatabase.createRandomPlayersIfEmpty()
//            }

            return appDatabase
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate.
            //
            // Typical reasons for an error here include:
            // * The parent directory cannot be created, or disallows writing.
            // * The database is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The database could not be migrated to its latest schema version.
            // Check the error message to determine what the actual problem was.
            fatalError("Unresolved error \(error)")
        }
    }

    /// Creates an empty database for SwiftUI previews
    static func empty() -> AppDatabase {
        // Connect to an in-memory database
        // See https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections
        let dbQueue = try! DatabaseQueue()
        return try! AppDatabase(dbQueue)
    }
}

// MARK: - Database Access: Reads

// This demo app does not provide any specific reading method, and instead
// gives an unrestricted read-only access to the rest of the application.
// In your app, you are free to choose another path, and define focused
// reading methods.
extension AppDatabase {
    /// Provides a read-only access to the database
    var reader: DatabaseReader {
        dbWriter
    }
}

struct User: Identifiable, Equatable, Hashable, TableRecord {
    var id: Int64?
    var name: String

    static let posts = hasMany(Post.self, using: Post.userForeignKey)
}

extension User: Codable, FetchableRecord, MutablePersistableRecord {
    fileprivate enum Columns {
        static let name = Column(CodingKeys.name)
    }

    /// Updates a user id after it has been inserted in the database.
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension User {
    var posts: QueryInterfaceRequest<Post> {
        request(for: User.posts)
    }
}

struct Post: Identifiable, Equatable, Hashable, TableRecord {
    var id: Int64?
    var content: String
    var userId: Int64

    static let userForeignKey = ForeignKey(["userId"])
    static let user = belongsTo(User.self, using: userForeignKey)
}

extension Post: Codable, FetchableRecord, MutablePersistableRecord {
    fileprivate enum Columns {
        static let content = Column(CodingKeys.content)
    }

    /// Updates a post id after it has been inserted in the database.
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Post {
    var user: QueryInterfaceRequest<User> {
        request(for: Post.user)
    }
}
