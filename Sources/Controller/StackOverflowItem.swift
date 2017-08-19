//
//  StackOverflowItem.swift
//  Kitura-Starter
//
//  Created by B Gay on 8/18/17.
//
//

import Foundation
import SwiftyJSON

struct StackOverflowItem
{
    let tags: [String]
    let owner: StackOverflowOwner
    let isAnswered: Bool
    let viewCount: Int
    let acceptedAnswerID: Int
    let answerCount: Int
    let score: Int
    let lastActivityDate: Date
    let creationDate: Date
    let lastEditDate: Date
    let questionID: Int
    let link: URL?
    let title: String
}

extension StackOverflowItem
{
    init(json: JSON)
    {
        self.tags = (json["tags"].arrayObject as? [String]) ?? []
        self.owner = StackOverflowOwner(json: json["owner"])
        self.isAnswered = json["is_answered"].boolValue
        self.viewCount = json["view_count"].intValue
        self.acceptedAnswerID = json["accepted_answer_id"].intValue
        self.answerCount = json["answer_count"].intValue
        self.score = json["score"].intValue
        self.lastActivityDate = Date(timeIntervalSince1970: json["last_activity_date"].doubleValue)
        self.creationDate = Date(timeIntervalSince1970: json["creation_date"].doubleValue)
        self.lastEditDate = Date(timeIntervalSince1970: json["last_edit_date"].doubleValue)
        self.questionID = json["question_id"].intValue
        self.link = URL(string: json["link"].stringValue)
        self.title = json["title"].stringValue
    }
}

struct StackOverflowOwner
{
    let reputation: Int
    let userID: Int
    let userType: String
    let acceptRate: Int
    let profileImage: URL?
    let displayName: String
    let link: URL?
}

extension StackOverflowOwner
{
    init(json: JSON)
    {
        self.reputation = json["reputation"].intValue
        self.userID = json["user_id"].intValue
        self.userType = json["user_type"].stringValue
        self.acceptRate = json["accept_rate"].intValue
        self.profileImage = URL(string: json["profile_image"].stringValue)
        self.displayName = json["display_name"].stringValue
        self.link = URL(string: json["link"].stringValue)
    }
}


