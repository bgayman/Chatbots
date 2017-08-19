//
//  JeopardyQuestion.swift
//  Kitura-Starter
//
//  Created by B Gay on 8/18/17.
//
//

import Foundation
import SwiftyJSON

struct JeopardyQuestion
{
    static let dateFormatter: DateFormatter =
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return dateFormatter
    }()
    
    let id: Int
    let answer: String
    let question: String
    let value: Int
    let airdate: Date?
    let createdAt: Date?
    let updatedAt: Date?
    let categoryID: Int
    let gameID: Int?
    let invalidCount: Int?
    let category: JeopardyCategory
}

extension JeopardyQuestion
{
    init(json: JSON)
    {
        self.id = json["id"].intValue
        self.answer = json["answer"].stringValue
        self.question = json["question"].stringValue
        self.value = json["value"].intValue
        self.airdate = JeopardyQuestion.dateFormatter.date(from: json["airdate"].stringValue)
        self.createdAt = JeopardyQuestion.dateFormatter.date(from: json["created_at"].stringValue)
        self.updatedAt = JeopardyQuestion.dateFormatter.date(from: json["updated_at"].stringValue)
        self.categoryID = json["category_id"].intValue
        self.gameID = json["game_id"].int
        self.invalidCount = json["invalid_count"].int
        self.category = JeopardyCategory(json: json["category"])
    }
}

struct JeopardyCategory
{
    let id:Int
    let title: String
    let createdAt: Date?
    let updatedAt: Date?
    let cluesCount: Int
}

extension JeopardyCategory
{
    init(json: JSON)
    {
        self.id = json["id"].intValue
        self.title = json["title"].stringValue
        self.createdAt = JeopardyQuestion.dateFormatter.date(from: json["created_at"].stringValue)
        self.updatedAt = JeopardyQuestion.dateFormatter.date(from: json["updated_at"].stringValue)
        self.cluesCount = json["clues_count"].intValue
    }
}

