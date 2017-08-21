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
import Dispatch

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
    let staticServer = StaticFileServer()
    fileprivate let separatorCharacter: Character = "/"
    fileprivate var separator: String
    {
        return String(separatorCharacter)
    }
    
    var rootDirectory: URL
    {
        #if os(Linux)
            return URL(fileURLWithPath: self.getAbsolutePath(for:"\(FileManager().currentDirectoryPath)/public/images"))
        #else
            return URL(fileURLWithPath: self.getAbsolutePath(for: "Chatbots/public/images"))
        #endif
    }
    var originalsDirectory: URL
    {
        return self.rootDirectory.appendingPathComponent("originals")
    }
    
    var finalDirectory: URL
    {
        return self.rootDirectory.appendingPathComponent("final")
    }
    
    public var port: Int
    {
        get { return configMgr.port }
    }
    
    public var url: String {
        get { return configMgr.url }
    }
    
    public init() {
        
        #if os(Linux)
            srand(UInt32(time(nil)))
        #endif
        
        configMgr = ConfigurationManager().load(.environmentVariables)
        
        // All web apps need a Router instance to define routes
        router = Router()
        
        // Instance of health for reporting heath check values
        health = Health()
        
        // Serve static content from "public"
        router.all("/", middleware: staticServer)
        
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
        router.post("/askChatbotEinstein", handler: handleAskChatbotEinstein)
        router.get("/asciiArt/:keywords", handler: getAsciiArt)
        router.get("/stackOverflow/:keywords", handler: getStackOverflow)
        router.get("/faceDetect/:url", handler: getFaceDetect)
    }
    
    // MARK: - Einstein
    private func getFaceDetect(request: RouterRequest, response: RouterResponse, next: () -> Void)
    {
        defer
        {
            next()
        }
        guard let encodedURL = request.parameters["url"],
              let decodedURL = encodedURL.removingPercentEncoding,
              let url = URL(string: decodedURL) else { return }
        let (finalURL, _) = processImage(url: url)
        response.send(finalURL?.absoluteString ?? "Could not process image")
    }
    
    private func handleAskChatbotEinstein(request: RouterRequest, response: RouterResponse, next: () -> Void)
    {
        defer
        {
            next()
        }
        let requestData = try? request.readString()
        Log.info(requestData.debugDescription)
        guard let readString = requestData else { return }
        let slackRequest = SlackRequest(payload: readString ?? "")
        guard let url = URL(string: slackRequest.text?.removingPercentEncoding ?? "") else { return }
        response.send("Time is relative, so that might be why it seems like this is taking a long time")
        DispatchQueue.global(qos: .background).async
        {
            let (einsteinImageURL, faces) = self.processImage(url: url)
            guard let imageURL = einsteinImageURL else { return }
            let attachment = SlackMessageAttachment(watsonFace: faces.first, imageURL: imageURL)
            let json: [String: Any] = ["response_type": "in_channel",
                                       "text": "\(url.absoluteString)",
                                       "attachments": [attachment.json]]
            Log.error(json.debugDescription)
            self.postEinsteinResponse(at: slackRequest.responseURL, json: JSON(json))
        }
    }
    
    private func processImage(url: URL) -> (URL?, [WatsonFace])
    {
        guard let faces = sendImageToWatson(imageURL: url) else { return (nil, []) }
        Log.info(faces.description)
        return (draw(faces: faces, imageURL: url), faces)
    }
    
    private func draw(faces: [WatsonFace], imageURL: URL) -> URL?
    {
        let name = imageURL.lastPathComponent
        Log.info(imageURL.absoluteString)
        var image = self.image(for: imageURL.absoluteString, shouldResize: false)
        Log.info(image.debugDescription)
        let einsteinURL = randomEinsteinURL()
        Log.info(einsteinURL)
        for face in faces
        {
            var einsteinImage = self.image(for: einsteinURL, shouldResize: false)
            einsteinImage = einsteinImage?.resizedTo(height: Int(Double(face.faceLocation.height) * 1.6))
            let faceMidX = face.faceLocation.left + Int(round(Double(face.faceLocation.width) * 0.5))
            let faceMidY = face.faceLocation.top + Int(round(Double(face.faceLocation.height) * 0.25))
            
            let startPointX = faceMidX - Int(round(Double(einsteinImage?.size.width ?? 0) * 0.5))
            let startPointY = faceMidY - Int(round(Double(einsteinImage?.size.height ?? 0) * 0.5))

            let startPoint = Point(x: startPointX, y: startPointY)
            
            for i in 0 ..< (einsteinImage?.size.height ?? 0)
            {
                for j in 0 ..< (einsteinImage?.size.width ?? 0)
                {
                    let point = Point(x: startPoint.x + j, y: startPoint.y + i)
                    if let imageColor = image?.get(pixel: point),
                       let einsteinColor = einsteinImage?.get(pixel: Point(x: j, y: i))
                    {
                        let outputColor = colorFor(backgroundColor: imageColor, overlayColor: einsteinColor)
                        image?.set(pixel: point, to: outputColor)
                    }
                }
            }
        }
        image = image?.resizedTo(width: 450)
        let newURL = finalDirectory.appendingPathComponent(name)
        Log.info(newURL.absoluteString)
        let success = image?.write(to: newURL)
        Log.info(success.debugDescription)
        return URL(string: "\(self.url)/images/final/\(name)")
    }
    
    private func postEinsteinResponse(at responseURL: URL?, json: JSON?)
    {
        guard let responseURL = responseURL,
              let json = json else { return }
        let requestOptions: [ClientRequest.Options] = [
            .method("POST"),
            .schema(responseURL.scheme ?? ""),
            .hostname(responseURL.host ?? ""),
            .path(responseURL.path),
            .headers(["content-type": "application/json"])
        ]
        var responseBody = Data()
        let request = HTTP.request(requestOptions)
        { (response) in
            if let response = response
            {
                Log.info("\(response.statusCode.rawValue)")
                guard response.statusCode == .OK else { return }
                _ = try? response.readAllData(into: &responseBody)
            }
        }
        request.write(from: json.rawString() ?? "")
        request.end()
    }
    
    private func colorFor(backgroundColor: Color, overlayColor: Color) -> Color
    {
        let outputRed = (overlayColor.redComponent * overlayColor.alphaComponent) + (backgroundColor.redComponent * (1.0 - overlayColor.alphaComponent))
        let outputGreen = (overlayColor.greenComponent * overlayColor.alphaComponent) + (backgroundColor.greenComponent * (1.0 - overlayColor.alphaComponent))
        let outputBlue = (overlayColor.blueComponent * overlayColor.alphaComponent) + (backgroundColor.blueComponent * (1.0 - overlayColor.alphaComponent))
        let outputAlpha = max(backgroundColor.alphaComponent, overlayColor.alphaComponent)
        return Color(red: outputRed, green: outputGreen, blue: outputBlue, alpha: outputAlpha)
    }
    
    private func sendImageToWatson(imageURL: URL) -> [WatsonFace]?
    {
        guard let url = URL(string: "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/detect_faces?api_key=b78348e9d39118131c255bf670cbe5fe982d0fd4&url=\(imageURL.absoluteString)&version=2016-05-20"),
              let data = try? Data(contentsOf: url) else { return nil }
        let json = JSON(data: data)
        guard let imageJSON = json["images"].arrayValue.first else { return nil }
        let facesJSON = imageJSON["faces"].arrayValue
        Log.info(facesJSON.debugDescription)
        return facesJSON.map(WatsonFace.init)
    }
    
    private func resizeImage(url: URL) -> URL?
    {
        guard let imageData = getImageData(for: url.absoluteString) else { return nil }
        let name = url.lastPathComponent
        let tempName = NSTemporaryDirectory().appending(name)
        let tempURL = URL(fileURLWithPath: tempName)
        Log.info(tempURL.absoluteString)
        _ = try? imageData.write(to: tempURL)
        
        if var image = Image(url: tempURL)
        {
            image = image.resizedTo(height: 300) ?? image
            let newURL = originalsDirectory.appendingPathComponent(name)
            image.write(to: newURL)
            return newURL
        }
        return nil
    }
    
    private func randomEinsteinURL() -> String
    {
        return "\(self.url)/einstein\(Int.random(9)).png"
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
    
    private func image(for path: String, shouldResize: Bool = true) -> Image?
    {
        guard let imageData = getImageData(for: path),
              let url = URL(string: path) else { return nil }
        
        let tempName = NSTemporaryDirectory().appending(url.lastPathComponent)
        let tempURL = URL(fileURLWithPath: tempName)
        Log.info(tempURL.absoluteString)
        _ = try? imageData.write(to: tempURL)

        if var image = Image(url: tempURL)
        {
            if shouldResize
            {
                image = image.resizedTo(height: 80) ?? image
            }
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

extension Controller
{
    fileprivate func getAbsolutePath(for path: String) -> String
    {
        var path = path
        if path.hasSuffix(separator) && path != separator {
            path = String(path.characters.dropLast())
        }
        
        // If we received a path with a tilde (~) in the front, expand it.
        path = NSString(string: path).expandingTildeInPath
        
        if isAbsolute(path: path) {
            return path
        }
        
        let fileManager = FileManager()
        
        let absolutePath = fileManager.currentDirectoryPath + separator + path
        if fileManager.fileExists(atPath: absolutePath) {
            return absolutePath
        }
        
        // the file does not exist on a path relative to the current working directory
        // return the path relative to the original repository directory
        guard let originalRepositoryPath = getOriginalRepositoryPath() else {
            return absolutePath
        }
        
        return originalRepositoryPath + separator + path
    }
    
    fileprivate func getOriginalRepositoryPath() -> String?
    {
        // this file is at
        // <original repository directory>/Sources/Kitura/staticFileServer/ResourcePathHandler.swift
        // the original repository directory is four path components up
        let currentFilePath = #file
        
        var pathComponents =
            currentFilePath.characters.split(separator: separatorCharacter).map(String.init)
        let numberOfComponentsFromKituraRepositoryDirectoryToThisFile = 4
        
        guard pathComponents.count >= numberOfComponentsFromKituraRepositoryDirectoryToThisFile else {
            Log.error("unable to get original repository path for \(currentFilePath)")
            return nil
        }
        
        pathComponents.removeLast(numberOfComponentsFromKituraRepositoryDirectoryToThisFile)
        pathComponents = removePackagesDirectory(pathComponents: pathComponents)
        
        return separator + pathComponents.joined(separator: separator)
    }
    
    fileprivate func removePackagesDirectory(pathComponents: [String]) -> [String]
    {
        var pathComponents = pathComponents
        let numberOfComponentsFromKituraPackageToDependentRepository = 3
        let packagesComponentIndex = pathComponents.endIndex - numberOfComponentsFromKituraPackageToDependentRepository
        if pathComponents.count > numberOfComponentsFromKituraPackageToDependentRepository &&
            pathComponents[packagesComponentIndex] == ".build"  &&
            pathComponents[packagesComponentIndex+1] == "checkouts" {
            pathComponents.removeLast(numberOfComponentsFromKituraPackageToDependentRepository)
        }
        else {
            let numberOfComponentsFromEditableKituraPackageToDependentRepository = 2
            let editablePackagesComponentIndex = pathComponents.endIndex - numberOfComponentsFromEditableKituraPackageToDependentRepository
            if pathComponents.count > numberOfComponentsFromEditableKituraPackageToDependentRepository &&
                pathComponents[editablePackagesComponentIndex] == "Packages" {
                pathComponents.removeLast(numberOfComponentsFromEditableKituraPackageToDependentRepository)
            }
        }
        return pathComponents
    }
    
    fileprivate func isAbsolute(path: String) -> Bool
    {
        return path.hasPrefix(separator)
    }
}

extension Int {
    static func random(_ max: Int) -> Int
    {
        #if os(Linux)
            return Glibc.random() % max
        #else
            return Int(arc4random_uniform(UInt32(max)))
        #endif
    }
}
