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
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()
    
    let id: String
    let answer: String
    let question: String
    let value: String
    let airdate: Date?
    let category: String
    let gameID: Int?
    
    var json: [String: Any]
    {
        return ["_id": self.id,
                "answer": self.answer,
                "question": self.question,
                "value": self.value,
                "airdate": self.airdate?.timeIntervalSince1970 as Any,
                "category": self.category,
                "showNumber": self.gameID as Any
        ]
    }
}

extension JeopardyQuestion
{
    init(json: JSON)
    {
        let idJSON = json["_id"]
        self.id = idJSON["$oid"].stringValue
        self.answer = json["answer"].stringValue
        self.question = json["question"].stringValue
        self.value = json["value"].stringValue
        self.airdate = JeopardyQuestion.dateFormatter.date(from: json["air_date"].stringValue)
        self.category = json["category"].stringValue
        self.gameID = json["show_number"].int
    }
}

