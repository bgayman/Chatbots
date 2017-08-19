//
//  SlackMessageAttachment.swift
//  Chatbot
//
//  Created by B Gay on 8/16/17.
//
//

import Foundation
import SwiftyJSON

struct SlackMessageAttachment
{
    static let dateFormatter: DateFormatter =
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }()
    
    var fallback: String = "Ascii Art couldn't not be created. Try again Picasso!"
    var color: String = "89c623"
    var pretext: String?
    var authorName: String = "AsciiBot"
    var authorLink: String = "http://kitura-starter-pseudocorneous-aardwolf.mybluemix.net"
    var authorIcon: String = "http://kitura-starter-pseudocorneous-aardwolf.mybluemix.net/icon.jpg"
    var title: String?
    var titleLink: String?
    var text: String?
    var imageURL: String?
    var footer: String?
    var footerIcon: String?
    var timestamp: Int = Int(Date().timeIntervalSince1970)
}

extension SlackMessageAttachment
{
    var json: [String: Any]
    {
        var dictionary: [String: Any] = ["fallback": fallback,
                                         "color": color,
                                         "time": timestamp,
                                         "author_name": authorName,
                                         "author_link": authorLink,
                                         "author_icon": authorIcon,
                                         "ts": timestamp
                                         ]
        if let pretext = pretext
        {
            dictionary["pretext"] = pretext
        }
        if let title = title
        {
            dictionary["title"] = title
        }
        if let titleLink = titleLink
        {
            dictionary["title_link"] = titleLink
        }
        if let text = text
        {
            dictionary["text"] = text
        }
        if let imageURL = imageURL
        {
            dictionary["image_url"] = imageURL
        }
        if let footer = footer
        {
            dictionary["footer"] = footer
        }
        if let footerIcon = footerIcon
        {
            dictionary["footer_icon"] = footerIcon
        }
        return dictionary
    }
    
    init(stackOverflowItem: StackOverflowItem)
    {
        self.color = "f48024"
        self.fallback = stackOverflowItem.title
        self.authorName = stackOverflowItem.owner.displayName
        self.authorIcon = stackOverflowItem.owner.profileImage?.absoluteString ?? ""
        self.authorLink = stackOverflowItem.owner.link?.absoluteString ?? ""
        self.title = stackOverflowItem.title
        self.titleLink = stackOverflowItem.link?.absoluteString
        self.text = "\(stackOverflowItem.viewCount) views"
        self.imageURL = "http://kitura-starter-pseudocorneous-aardwolf.mybluemix.net/so-icon.png"
        self.footer = stackOverflowItem.isAnswered ? "Answered" : "Not Answered"
        self.timestamp = Int(stackOverflowItem.creationDate.timeIntervalSince1970)
    }
    
    init(jeopardyQuestion: JeopardyQuestion)
    {
        self.color = "4614c1"
        self.fallback = jeopardyQuestion.question
        self.authorName = "Alex Trebek"
        self.authorIcon = "http://www.thefamouspeople.com/profiles/images/alex-trebek-2.jpg"
        self.authorLink = "https://en.wikipedia.org/wiki/Alex_Trebek"
        self.title = jeopardyQuestion.question
        self.text = "Category: " + jeopardyQuestion.category.title + "\n" + "Point Value: " + String(jeopardyQuestion.value)
        self.footer = "Answer: " + jeopardyQuestion.answer.reversed
        if let airdate = jeopardyQuestion.airdate
        {
            self.timestamp = Int(airdate.timeIntervalSince1970)
        }
    }
}

extension String
{
    var reversed: String
    {
        var reverse = ""
        
        for character in self.characters
        {
            let asString = "\(character)"
            reverse = asString + reverse
        }
        return reverse
    }
}
