//
//  GRDBDemoTests.swift
//  GRDBDemoTests
//
//  Created by David Reed on 4/2/23.
//

import XCTest
import GRDB
@testable import GRDBDemo

final class GRDBDemoTests: XCTestCase {

//    override func setUpWithError() throws {
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//
//    override func tearDownWithError() throws {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }

    func testInsertUsersAndPosts() throws {
        let dbQueue = try DatabaseQueue()
        _ = try AppDatabase(dbQueue)

        var tom = User(name: "Tom")
        var jane = User(name: "Jane")

        try dbQueue.write { db in
            try jane.insert(db)
            try tom.insert(db)
        }

        var tomP1 = Post(content: "Tom's first post", userId: tom.id!)
        var tomP2 = Post(content: "Tom's second post", userId: tom.id!)
        var janeP1 = Post(content: "Jane's first post", userId: jane.id!)

        try dbQueue.write { db in
            try tomP1.insert(db)
            try tomP2.insert(db)
            try janeP1.insert(db)
        }

        struct PostInfo: Decodable, FetchableRecord {
            var post: Post
            var user: User
        }

        try dbQueue.read { db in
            let rows = try Post
                .including(required: Post.user)
                .asRequest(of: PostInfo.self)
                .fetchAll(db)
            let actualPosts = Set(rows.map { $0.post })
            let expectedPosts = Set([tomP1, tomP2, janeP1])
            XCTAssertEqual(expectedPosts, actualPosts)

            let actualUsers = Set(rows.map { $0.user })
            let expectedUsers = Set([tom, jane])
            XCTAssertEqual(expectedUsers, actualUsers)
        }

        struct UserInfo: Decodable, FetchableRecord {
            var user: User
            var posts: [Post]
        }

        try dbQueue.read { db in
            let rows = try User
                .including(all: User.posts)
                .asRequest(of: UserInfo.self)
                .order(Column("name"))
                .fetchAll(db)
            XCTAssertEqual(rows[0].user, jane)
            XCTAssertEqual(rows[0].posts, [janeP1])
            XCTAssertEqual(rows[1].user, tom)
            XCTAssertEqual(rows[1].posts, [tomP1, tomP2])
        }

        try dbQueue.read { db in
            let rows = try Post
                .filter(literal: "userId = \(tom.id)")
                .order(Column("content"))
                .fetchAll(db)
            XCTAssertEqual(rows[0], tomP1)
            XCTAssertEqual(rows[1], tomP2)
        }

        let tomPosts = try dbQueue.read { db in
            try tom.posts.fetchAll(db)
        }
        XCTAssertEqual(tomPosts[0], tomP1)
        XCTAssertEqual(tomPosts[1], tomP2)
    }
}
