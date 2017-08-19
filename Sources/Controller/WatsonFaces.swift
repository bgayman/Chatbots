//
//  WatsonFaces.swift
//  Kitura-Starter
//
//  Created by B Gay on 8/19/17.
//
//

import Foundation
import SwiftyJSON

struct WatsonFace
{
    let age: Age
    let faceLocation: FaceLocation
    let gender: Gender
    let identity: Identity?
}

extension WatsonFace
{
    init(json: JSON)
    {
        self.age = Age(json: json["age"])
        self.faceLocation = FaceLocation(json: json["face_location"])
        self.gender = Gender(json: json["gender"])
        self.identity = Identity(json: json["identity"])
    }
}

struct Identity
{
    let name: String
    let score: Double
    let type: String
}

extension Identity
{
    init?(json: JSON)
    {
        guard let name = json["name"].string,
              let score = json["score"].double,
              let type = json["type_hierarchy"].string else { return nil }
        self.name = name
        self.score = score
        self.type = type
    }
}

struct Gender
{
    let gender: String
    let score: Double
}

extension Gender
{
    init(json: JSON)
    {
        self.gender = json["gender"].stringValue
        self.score = json["score"].doubleValue
    }
}

struct FaceLocation
{
    let height: Int
    let left: Int
    let top: Int
    let width: Int
}

extension FaceLocation
{
    init(json: JSON)
    {
        self.height = json["height"].intValue
        self.left = json["left"].intValue
        self.top = json["top"].intValue
        self.width = json["width"].intValue
    }
}

struct Age
{
    let max: Int
    let min: Int
    let score: Double
}

extension Age
{
    init(json: JSON)
    {
        self.max = json["max"].intValue
        self.min = json["min"].intValue
        self.score = json["score"].doubleValue
    }
}


