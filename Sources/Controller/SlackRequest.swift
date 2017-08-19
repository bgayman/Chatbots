//
//  SlackRequest.swift
//  Kitura-Starter
//
//  Created by B Gay on 8/16/17.
//
//

import Foundation
import SwiftyJSON

public enum SlackItem: String
{
    case token
    case teamID = "team_id"
    case teamDomain = "team_domain"
    case channelID = "channel_id"
    case channelName = "channel_name"
    case userID = "user_id"
    case userName = "user_name"
    case command
    case text
    case responseURL = "response_url"
}


public struct SlackRequest
{
    public var token: String?
    public var teamID: String?
    public var teamDomain: String?
    public var channelID: String?
    public var channelName: String?
    public var userID: String?
    public var userName: String?
    public var command: String?
    public var text: String?
    public var responseURL: String? = ""
    
    public init(payload: String)
    {
        let elementPairs = payload.components(separatedBy: "&")
        for element in elementPairs
        {
            let elementItem = element.components(separatedBy: "=")
            guard let slackItem = SlackItem(rawValue: elementItem[0]) else { continue }
            switch slackItem
            {
            case .token:
                token = elementItem[1]
            case .teamID:
                teamID = elementItem[1]
            case .teamDomain:
                teamDomain = elementItem[1]
            case .channelID:
                channelID = elementItem[1]
            case .channelName:
                channelName = elementItem[1]
            case .userID:
                userID = elementItem[1]
            case .userName:
                userName = elementItem[1]
            case .command:
                command = elementItem[1]
            case .text:
                text = elementItem[1]
            case .responseURL:
                responseURL = elementItem[1]
            }
        }
    }
}
