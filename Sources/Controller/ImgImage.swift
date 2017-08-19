//
//  ImgImage.swift
//  Kitura-Starter
//
//  Created by B Gay on 8/17/17.
//
//

import Foundation
import SwiftyJSON

enum ImageType: String
{
    case jpg = "image/jpeg"
    case png = "image/png"
}

struct ImgImage
{
    let type: ImageType
    let link: String
}


extension ImgImage
{
    init?(json: JSON)
    {
        guard let type = ImageType(rawValue: json["type"].stringValue),
              let link = json["link"].string else { return nil }
        self.type = type
        self.link = link
    }
}
