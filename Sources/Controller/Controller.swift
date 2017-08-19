/**
 * Copyright IBM Corporation 2016,2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import Kitura
import SwiftyJSON
import LoggerAPI
import Configuration
import CloudFoundryEnv
import CloudFoundryConfig
import Health
import KituraNet
import SwiftGD
import KituraRequest

struct Configuration
{
    static let staticGeocode = ""
    static let slackToken = "BvmakmuY4lULNFrwOrHF4RJj"
    static let classifierID = ""
    static let weatherPassword = ""
    static let naturalLanguageClassifierUsername = ""
    static let naturalLanguageClassifierPassword = ""
}

public class Controller {
    
    public let router: Router
    let configMgr: ConfigurationManager
    let health: Health
    
    public var port: Int {
        get { return configMgr.port }
    }
    
    public var url: String {
        get { return configMgr.url }
    }
    
    public init() {
        configMgr = ConfigurationManager().load(.environmentVariables)
        
        // All web apps need a Router instance to define routes
        router = Router()
        
        // Instance of health for reporting heath check values
        health = Health()
        
        // Serve static content from "public"
        router.all("/", middleware: StaticFileServer())
        
        // Basic GET request
        router.get("/hello", handler: getHello)
        
        // Basic POST request
        router.post("/hello", handler: postHello)
        
        // JSON Get request
        router.get("/json", handler: getJSON)
        
        // Basic application health check
        router.get("/health", handler: getHealthCheck)
        
        router.post("/askChatbot", handler: handleAskChatbot)
        router.post("/askChatbotStackOverflow", handler: handleAskChatbotStackOverflow)
        router.post("/askChatbotJeopardy", handler: handleAskChatbotJeopardy)
        router.get("/asciiArt/:keywords", handler: getAsciiArt)
        router.get("/stackOverflow/:keywords", handler: getStackOverflow)
    }
    
    // MARK: - Jeopardy
    private func handleAskChatbotJeopardy(request: RouterRequest, response: RouterResponse, next: () -> Void)
    {
        defer
        {
            next()
        }
        let requestData = try? request.readString()
        Log.info(requestData.debugDescription)
        guard let readString = requestData else { return }
        let slackRequest = SlackRequest(payload: readString ?? "")
        let jeopardyQuestions = getJeopardyQuestions(count: Int(slackRequest.text ?? ""))
        let attachments = jeopardyQuestions.map(SlackMessageAttachment.init).map { $0.json }
        let json: [String: Any] = ["response_type": "in_channel",
                                   "text": "This is Jeopardy",
                                   "attachments": attachments]
        Log.error(json.debugDescription)
        response.send(json: json)
    }
    
    private func getJeopardyQuestions(count: Int?) -> [JeopardyQuestion]
    {
        guard let json = getJeopardyJSON(count: count) else { return [] }
        let jeopardyQuestions = json.arrayValue.map(JeopardyQuestion.init)
        return jeopardyQuestions
    }
    
    private func getJeopardyJSON(count: Int?) -> JSON?
    {
        let path = count == nil ? "http://jservice.io/api/random" : "http://jservice.io/api/random?count=\(count!)"
        guard let url = URL(string: path) else { return nil }
        do
        {
            let data = try Data(contentsOf: url)
            let json = JSON(data: data)
            Log.info(json.debugDescription)
            return json
        }
        catch
        {
            Log.info(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - StackOverflow
    private func handleAskChatbotStackOverflow(request: RouterRequest, response: RouterResponse, next: () -> Void)
    {
        defer
        {
            next()
        }
        let requestData = try? request.readString()
        Log.info(requestData.debugDescription)
        guard let readString = requestData else { return }
        
        let slackRequest = SlackRequest(payload: readString ?? "")
        let stackOverflowItems = getStackItems(for: slackRequest.text)
        var attachments = stackOverflowItems.flatMap(SlackMessageAttachment.init).map { $0.json }
        attachments = Array(attachments.prefix(5))
        let json: [String: Any] = ["response_type": "in_channel",
                                   "text": stackOverflowItems.first?.link?.absoluteString ?? "",
                                   "attachments": attachments]
        Log.error(json.debugDescription)
        response.send(json: json)
    }
    
    private func getStackOverflow(request: RouterRequest, response: RouterResponse, next: () -> Void)
    {
        guard let keywords = request.parameters["keywords"] else { return }
        let stackOverflowItems = getStackItems(for: keywords)
        var attachments = stackOverflowItems.flatMap(SlackMessageAttachment.init).map { $0.json }
        attachments = Array(attachments.prefix(5))
        let json: [String: Any] = ["response_type": "in_channel",
                                   "text": stackOverflowItems.first?.link?.absoluteString ?? "",
                                   "attachments": attachments]
        Log.error(json.debugDescription)
        response.send(json: json)
    }
    
    private func getStackItems(for text: String?) -> [StackOverflowItem]
    {
        guard let text = text,
              let json = getStackJSON(for: text) else { return [] }
        Log.info(json.debugDescription)
        let items = json["items"].arrayValue.flatMap(StackOverflowItem.init)
        return items
    }
    
    private func getStackJSON(for text: String) -> JSON?
    {
        let text = text.replacingOccurrences(of: " ", with: "-")
        let path = "https://api.stackexchange.com/2.2/search?order=desc&sort=activity&intitle=\(text)&site=stackoverflow"
        guard let url = URL(string: path) else { return nil }
        do
        {
            let data = try Data(contentsOf: url)
            let json = JSON(data: data)
            Log.info(json.debugDescription)
            return json
        }
        catch
        {
            Log.info(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - AsciiArt
    private func handleAskChatbot(request: RouterRequest, response: RouterResponse, next: () -> Void)
    {
        defer
        {
            next()
        }
        
        let requestData = try? request.readString()
        Log.info(requestData.debugDescription)
        guard let readString = requestData else { return }
        
        let slackRequest = SlackRequest(payload: readString ?? "")
        let keywords = slackRequest.text?.replacingOccurrences(of: " ", with: ",") ?? ""
        Log.info(keywords)
        var slackMessage = SlackMessageAttachment()
        slackMessage.title = keywords
        slackMessage.titleLink = "https://asciiartchatbot.mybluemix.net/asciiArt/\(keywords)"
        let imgImage = self.imgImage(keywords: keywords)
        slackMessage.imageURL = imgImage?.link
        var output = asciiArt(imgImage: imgImage) ?? "Oh boy...something went wrong."
        output = "```\n" + output + "\n```"
        let json: [String: Any] = ["response_type": "in_channel",
                                   "text": output,
                                   "attachments": [slackMessage.json]]
        Log.error(slackMessage.json.debugDescription)
        response.send(json: json)
    }
    
    private func getAsciiArt(request: RouterRequest, response: RouterResponse, next: () -> Void)
    {
        defer
        {
            next()
        }
        
        guard let keywords = request.parameters["keywords"] else { return }
        let output = asciiString(keywords: keywords)
        response.send(output)
    }
    
    private func asciiArt(imgImage: ImgImage?) -> String?
    {
        guard let imageLinkString = imgImage?.link else { return nil }
        return asciiString(for: image(for: imageLinkString))
    }
    
    private func imgImage(keywords: String) -> ImgImage?
    {
        let json = getImgJSON(for: keywords)
        var imgImage: ImgImage?
        for data in json?["data"].arrayValue ?? []
        {
            let images = data["images"].array?.flatMap { ImgImage(json: $0) }
            if let image = images?.first
            {
                imgImage = image
                break
            }
        }
        return imgImage
    }
    
    private func asciiString(keywords: String) -> String
    {
        let imgImage = self.imgImage(keywords: keywords)
        guard let imageLinkString = imgImage?.link else { return "" }
        return asciiString(for: image(for: imageLinkString))
    }
    
    private func asciiString(for image: Image?) -> String
    {
        guard let image = image else {
            Log.error("No Image")
            return ""
        }
        let asciiBlocks = ["@", "#", "*", "+", ";", ":", ",", ".", "`", " "]
        let imageSize = image.size
        let blockSize = 2
        var rows = [[String]]()
        rows.reserveCapacity(imageSize.height)
        
        for y in stride(from: 0, to: imageSize.height, by: blockSize)
        {
            var row = [String]()
            row.reserveCapacity(imageSize.width)
            for x in stride(from: 0, to: imageSize.width, by: blockSize)
            {
                let color = image.get(pixel: Point(x: x, y: y))
                let brightness = color.redComponent + color.greenComponent + color.blueComponent
                let sum = Int(round(brightness * 3))
                row.append(asciiBlocks[sum])
            }
            rows.append(row)
        }
        let output = rows.reduce("")
        {
            $0.0 + $0.1.joined(separator: " ") + "\n"
        }
        Log.info(output)
        return output
    }
    
    private func image(for path: String) -> Image?
    {
        guard let imageData = getImageData(for: path),
            let url = URL(string: path) else { return nil }
        
        let tempName = NSTemporaryDirectory().appending(url.lastPathComponent)
        let tempURL = URL(fileURLWithPath: tempName)
        Log.info(tempURL.absoluteString)
        _ = try? imageData.write(to: tempURL)

        if var image = Image(url: tempURL)
        {
            image = image.resizedTo(height: 80) ?? image
            return image
        }
        Log.error("Image NIL")
        return nil
    }
    
    private func getImageData(for path: String) -> Data?
    {
        Log.info(path)
        var data = Data()
        let request = HTTP.get(path)
        { (response) in
            _ = try? response?.readAllData(into: &data)
        }
        request.end()
        if data.isEmpty == false
        {
            Log.info(data.description)
            return data
        }
        else
        {
            return nil
        }
        
    }
    
    private func getImgJSON(for keywords: String) -> JSON?
    {
        let requestOptions: [ClientRequest.Options] = [
            .method("GET"),
            .schema("https://"),
            .hostname("api.imgur.com"),
            .path("/3/gallery/search/?q=\(keywords)"),
            .headers(["Authorization": "Client-ID d977d69bce4f5c6"])
            
        ]
        var responseBody = Data()
        let request = HTTP.request(requestOptions)
        { (response) in
            if let response = response
            {
                guard response.statusCode == .OK else { return }
                _ = try? response.readAllData(into: &responseBody)
            }
        }
        request.end()
        if responseBody.count > 0
        {
            let json = JSON(data: responseBody)
            Log.info(json.stringValue)
            return json
        }
        else
        {
            return nil
        }
    }
    
    /**
     * Handler for getting a text/plain response.
     */
    public func getHello(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        Log.debug("GET - /hello route handler...")
        response.headers["Content-Type"] = "text/plain; charset=utf-8"
        try response.status(.OK).send("Hello from Kitura-Starter!").end()
    }
    
    /**
     * Handler for posting the name of the entity to say hello to (a text/plain response).
     */
    public func postHello(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        Log.debug("POST - /hello route handler...")
        response.headers["Content-Type"] = "text/plain; charset=utf-8"
        if let name = try request.readString() {
            try response.status(.OK).send("Hello \(name), from Kitura-Starter!").end()
        } else {
            try response.status(.OK).send("Kitura-Starter received a POST request!").end()
        }
    }
    
    /**
     * Handler for getting an application/json response.
     */
    public func getJSON(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        Log.debug("GET - /json route handler...")
        response.headers["Content-Type"] = "application/json; charset=utf-8"
        var jsonResponse = JSON([:])
        jsonResponse["framework"].stringValue = "Kitura"
        jsonResponse["applicationName"].stringValue = "Kitura-Starter"
        jsonResponse["company"].stringValue = "IBM"
        jsonResponse["organization"].stringValue = "Swift @ IBM"
        jsonResponse["location"].stringValue = "Austin, Texas"
        try response.status(.OK).send(json: jsonResponse).end()
    }
    
    /**
     * Handler for getting a text/plain response of application health status.
     */
    public func getHealthCheck(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        Log.debug("GET - /health route handler...")
        let result = health.status.toSimpleDictionary()
        if health.status.state == .UP {
            try response.send(json: result).end()
        } else {
            try response.status(.serviceUnavailable).send(json: result).end()
        }
    }
    
}
