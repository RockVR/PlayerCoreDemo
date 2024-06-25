//
//  url.swift
//  moon-player
//
//  Created by kail on 2024/1/16.
//

import Foundation
import WebKit
import Python
import PythonKit

var pyInit = false
let webview = getWebKit()
let originalUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"

class URLIdentifier {
    static var youtubeRegex = /youtube\.com\/watch\?v=[a-zA-Z0-9_-]+/
    static var pornhubRegex = /pornhub\.com\/view_video\.php\?viewkey=[a-zA-Z0-9]+/
    
    static func checkIfYoutube(_ url: String) -> Bool {
        let target = url
        return !target.matches(of: youtubeRegex).isEmpty
    }
    
    static func checkIfValid(_ url: String) -> Bool {
        let target = url
        return !target.matches(of: pornhubRegex).isEmpty
    }
}

func gotoTarget(urlString: String) {
    let url = URL(string: urlString)
    if url != nil {
        webview.customUserAgent = originalUserAgent
        let request = URLRequest(url: url!)
        webview.load(request)
    }
}

func parseUrlAndPlay() async -> currentPlayItem? {
    if let url = await webview.url {
        let urlString = url.absoluteString

        do {
            let cookieStore = await webview.configuration.websiteDataStore.httpCookieStore
            let cookies = await getAllCookiesAsync(cookieStore: cookieStore)
            var cookieFileArr = "# Netscape HTTP Cookie File\n"
            for cookie in cookies {
                if cookie.domain == ".youtube.com" && cookie.name.contains("__Secure") {
                    cookieFileArr.append("\(cookie.domain)\tTRUE\t\(cookie.path)\t\(cookie.isSecure ? "TRUE" : "FALSE")\t\(Int64(cookie.expiresDate?.timeIntervalSince1970 ?? 0))\t\(cookie.name)\t\(cookie.value)\n")
                }
            }
            // 强制执行两次停止播放, 避免本地播放器播放时候网页也在播放
            let streamUrl = try await parseOnlineVideo(url: urlString, cookie: cookieFileArr)
            return streamUrl
        } catch {
            print(error)
        }
    }
    return nil
}

func getWebKit() -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let preferences = WKPreferences()

    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = .video
    configuration.preferences = preferences
    configuration.mediaTypesRequiringUserActionForPlayback = .all

    let webView = WKWebView(frame: .zero, configuration: configuration)
    return webView
}

func getAllCookiesAsync(cookieStore: WKHTTPCookieStore) async -> [HTTPCookie] {
    await withCheckedContinuation { continuation in
        cookieStore.getAllCookies { cookies in
            continuation.resume(returning: cookies)
        }
    }
}

struct FormatDetail: Codable {
    var abr: Float32?
    var height: Int?
    var width: Int?
    var url: String?
    var format_note: String?
    var format_id: String
    var vcodec: String?
    var acodec: String?
    var `protocol`: String?
    var video_ext: String?
}

struct ResponseData: Codable {
    var title: String
    var is_live: Bool?
    var duration: Float64? = 0
    var formats: [FormatDetail] = []
    var requested_formats: [FormatDetail]?
}

let apiURI = "https://ytapi.moonvrplayer.com"

func extractVideoID(_ url: String) -> String {
    do {
        // 尝试创建正则表达式对象
        let regex = try NSRegularExpression(pattern: "(?:v=|\\/)([0-9A-Za-z_-]{11}).*", options: [])
        // 定义搜索的范围为整个字符串
        let range = NSRange(url.startIndex ..< url.endIndex, in: url)
        // 尝试找到第一个匹配的结果
        if let firstMatch = regex.firstMatch(in: url, options: [], range: range) {
            // 如果找到匹配，提取并返回匹配的视频ID
            if let range = Range(firstMatch.range(at: 1), in: url) {
                return String(url[range])
            }
        }
    } catch {
        // 如果正则表达式创建失败，打印错误信息
        print("Invalid regex: \(error.localizedDescription)")
    }
    // 如果没有找到匹配，返回nil
    return ""
}

func parseWithCookieRemote(id: String, cookie: String) async throws -> ResponseData {
    let urlString = "\(apiURI)/info?id=\(id)"
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL)
    }

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }

    let decodedData = try JSONDecoder().decode(ResponseData.self, from: data)
    return decodedData
}

func extractDomainAndPort(urlString: String) -> String? {
    guard let url = URL(string: urlString),
          let scheme = url.scheme,
          let host = url.host else {
        return nil
    }

    if let port = url.port {
        return "\(scheme)://\(host):\(port)"
    } else {
        return "\(scheme)://\(host)"
    }
}

enum ParserError: Error {
    case parseFail(String)
}

func genMultiPlayItemTest(originalUrlString: String, videoFormats: [FormatDetail], audioUrlString: String? = nil, title: String = "", duration: Int64 = 0) async throws -> currentPlayItem {
    if audioUrlString == nil {
        return currentPlayItem(title: title, originalUrl: originalUrlString, url: videoFormats.max { a, b in (a.height ?? 0) < (b.height ?? 0) }!.url ?? "")
    }
    let fileManager = FileManager.default
    let directory = try fileManager
        .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var index = """
    #EXTM3U
    """
    index += "\n"
    index += """
    #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-group",DEFAULT=YES,URI="\(audioUrlString!)"
    """

    let maxVideoFormat = videoFormats.max { a, b in (a.height ?? 0) < (b.height ?? 0) }!
    var resoSet: Set<String> = []
    for videoFormat in videoFormats {
        let autoSelect = (videoFormat.url == maxVideoFormat.url)
        let reso = "\(videoFormat.width ?? 0)x\(videoFormat.width ?? 0)"
        if !resoSet.contains(reso) {
            resoSet.insert(reso)
            index += "\n"
            index += """
            #EXT-X-STREAM-INF:RESOLUTION=\(reso),AUDIO="audio-group"
            \(videoFormat.url!)
            """
        }
    }

    let indexFile = directory.appendingPathComponent("index.m3u8")
//    try fileManager.removeItem(at: indexFile)
    try index.write(to: indexFile, atomically: true, encoding: .utf8)

    return currentPlayItem(title: title, originalUrl: originalUrlString, url: indexFile.absoluteString)
}

func genMultiPlayItem(originalUrlString: String, videoFormats: [FormatDetail], audioUrlString: String? = nil, title: String = "", duration: Int64 = 0) async throws -> currentPlayItem {
    if audioUrlString == nil {
        return currentPlayItem(title: title, originalUrl: originalUrlString, url: videoFormats.max { a, b in (a.height ?? 0) < (b.height ?? 0) }!.url ?? "")
    }
    let fileManager = FileManager.default
    let directory = try fileManager
        .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let audio =
        """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-ALLOW-CACHE:YES
        #EXT-X-TARGETDURATION:8
        #EXTINF:\(duration)
        \(audioUrlString!)
        #EXT-X-ENDLIST
        """
    let audioFile = directory.appendingPathComponent("audio.m3u8")
    try audio.write(to: audioFile, atomically: true, encoding: .utf8)
    var index = "#EXTM3U"
    var resoSet: Set<String> = []

    let maxVideoFormat = videoFormats.max { a, b in (a.height ?? 0) < (b.height ?? 0) }!

    for videoFormat in videoFormats {
        let autoSelect = (videoFormat.url == maxVideoFormat.url)
        let reso = "\(videoFormat.width ?? 0)x\(videoFormat.width ?? 0)"
        if !resoSet.contains(reso) {
            resoSet.insert(reso)
            let video = """
            #EXTM3U
            #EXT-X-VERSION:5
            #EXTINF:\(duration),video
            \(videoFormat.url ?? "")
            #EXT-X-ENDLIST
            """
            let main = """
            #EXTM3U
            #EXT-X-VERSION:5

            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="merge",DEFAULT=YES,AUTOSELECT=YES,URI="audio.m3u8"

            #EXT-X-STREAM-INF:PROGRAM-ID=1,AUDIO="audio"
            video-\(videoFormat.format_id).m3u8

            #EXT-X-ENDLIST
            """
            let videoFile = directory.appendingPathComponent("video-\(videoFormat.format_id).m3u8")
            let mainFile = directory.appendingPathComponent("main-\(videoFormat.format_id).m3u8")
//            try fileManager.removeItem(at: videoFile)
//            try fileManager.removeItem(at: mainFile)
            try main.write(to: mainFile, atomically: true, encoding: .utf8)
            try video.write(to: videoFile, atomically: true, encoding: .utf8)

            index.append("""

            #EXT-X-STREAM-INF:RESOLUTION=\(videoFormat.width ?? 0)x\(videoFormat.width ?? 0),\(autoSelect ? "AUTOSELECT=YES," : "")
            main-\(videoFormat.format_id).m3u8

            """)
        }
    }
    
    let indexFile = directory.appendingPathComponent("index.m3u8")
//    try fileManager.removeItem(at: indexFile)
    try index.write(to: indexFile, atomically: true, encoding: .utf8)

    return currentPlayItem(title: title, originalUrl: originalUrlString, url: indexFile.absoluteString)
}

func genPlayItem(originalUrlString: String, videoUrlString: String = "", audioUrlString: String? = nil, title: String = "", duration: Int64 = 0) async throws -> currentPlayItem {
    if audioUrlString == nil {
        return currentPlayItem(title: title, originalUrl: videoUrlString, url: videoUrlString)
    }
    let audio =
        """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-ALLOW-CACHE:YES
        #EXT-X-TARGETDURATION:8
        #EXTINF:\(duration)
        \(audioUrlString!)
        #EXT-X-ENDLIST
        """
    let video = """
    #EXTM3U
    #EXT-X-VERSION:5
    #EXTINF:\(duration),video
    \(videoUrlString)
    #EXT-X-ENDLIST
    """
    let main = """
    #EXTM3U
    #EXT-X-VERSION:5

    #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="merge",DEFAULT=YES,AUTOSELECT=YES,URI="audio.m3u8"

    #EXT-X-STREAM-INF:PROGRAM-ID=1,AUDIO="audio"
    video.m3u8

    #EXT-X-ENDLIST
    """
    let fileManager = FileManager.default
    let directory = try fileManager
        .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let mainFile = directory.appendingPathComponent("main.m3u8")
    let videoFile = directory.appendingPathComponent("video.m3u8")
    let audioFile = directory.appendingPathComponent("audio.m3u8")

//    try fileManager.removeItem(at: mainFile)
//    try fileManager.removeItem(at: videoFile)
//    try fileManager.removeItem(at: audioFile)

    try main.write(to: mainFile, atomically: true, encoding: .utf8)
    try video.write(to: videoFile, atomically: true, encoding: .utf8)
    try audio.write(to: audioFile, atomically: true, encoding: .utf8)

    return currentPlayItem(title: title, originalUrl: originalUrlString, url: mainFile.absoluteString)
}

func initPy() async throws {
    let stdLibPath = Bundle.main.path(forResource: "python-stdlib", ofType: nil)!
    let libDynloadPath = Bundle.main.path(forResource: "python-stdlib/lib-dynload", ofType: nil)!
    let bundlePath = Bundle.main.bundlePath

    setenv("PYTHONHOME", stdLibPath, 1)
    setenv("PYTHONPATH", "\(stdLibPath):\(libDynloadPath):\(bundlePath)", 1)
    Py_Initialize()
    let sys = Python.import("sys")

    let frameworkPath = Bundle.main.path(forResource: "Frameworks", ofType: nil)
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(atPath: frameworkPath!)

    while let element = enumerator?.nextObject() as? String {
        let fullPath = (frameworkPath! as NSString).appendingPathComponent(element)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue {
            sys.path.append(fullPath)
        }
    }
    
    pyInit = true
}

func parseWithCookie(id: String, cookie: String) async throws -> ResponseData {
    if !pyInit {
        try await initPy()
    }

    let fileManager = FileManager.default
    let directory = try fileManager
        .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    let mainFile = directory.appendingPathComponent("cookie.txt")
    
    let cookiePath = id.contains("youtube")

    try cookie.write(to: mainFile, atomically: true, encoding: .utf8)

    let dlp = Python.import("getytbinfo")

    dlp.updateCertifi()

    let info = "\(dlp.getInfo("\(id)", "\(cookiePath ? mainFile.path : "")"))"
    
    print(info)

    let result = try JSONDecoder().decode(ResponseData.self, from: info.data(using: .utf8)!)
    return result
}

func parseOnlineVideoDlp(_ url: String, _ cookie: String) async throws -> currentPlayItem {
    var _info: ResponseData?
    do {
        if URLIdentifier.checkIfYoutube(url) {
            _info = try await parseWithCookieRemote(id: url, cookie: cookie)
        } else if URLIdentifier.checkIfValid(url) {
            _info = try await parseWithCookie(id: url, cookie: cookie)
        }
    } catch {
        let errorMsg = "dlpError: \(error)"
        print("errorMsgDlp", errorMsg)
        //_info = try await parseWithCookieRemote(id: url, cookie: cookie)
    }
    
    guard let info = _info else {
         throw ParserError.parseFail("no parse info")
    }

    if info.formats.count == 0 {
        throw ParserError.parseFail("formats count is 0 !!! detail: (\(info)")
    }

    if info.is_live ?? false {
        let bestFormat = info.formats.max { a, b in (a.height ?? 0) < (b.height ?? 0) }
        return currentPlayItem(title: info.title, originalUrl: url, url: (bestFormat?.url!)!)
    }

    let formats = info.formats.filter { $0.url != "" && $0.protocol == "https" }

    let hasVideoFromats = formats.filter { ($0.height ?? 0) != 0 }
    let pureAudioFromats = formats.filter { ($0.acodec ?? "none") != "none" && ($0.height ?? 0) == 0 && $0.format_note?.contains("ambisonic") == false }
    let bestAudioFromat = pureAudioFromats.max { a, b in (a.abr ?? 0) < (b.abr ?? 0) }

    let meshVideos = hasVideoFromats.filter { ($0.format_note ?? "").contains("mesh") || ($0.format_note ?? "").contains("equi") }

    let selectedVideoList = meshVideos.count > 0 ? meshVideos : hasVideoFromats

    var bestVideoFormat = selectedVideoList.max { a, b in
        (a.height ?? 0 + ((a.video_ext == "mp4") ? 1 : 0)) < (b.height ?? 0 + ((b.video_ext == "mp4") ? 1 : 0))
    }!

    if info.requested_formats?.first != nil {
        bestVideoFormat = (info.requested_formats?.first!)!
    }

    let playItem = try await genPlayItem(originalUrlString: url, videoUrlString: bestVideoFormat.url ?? "", audioUrlString: bestAudioFromat?.url, title: info.title, duration: Int64(info.duration ?? 0))
    return playItem
}

func parseOnlineVideo(url: String, cookie: String) async throws -> currentPlayItem {
    if !url.contains("pornhub") && !url.contains("youtube") {
        throw ParserError.parseFail("not invalid page")
    }
    do {
        return try await parseOnlineVideoDlp(url, cookie)
    } catch {
        let errorMsg = "\(error)"
        print("errorMsgLog", errorMsg)
        throw ParserError.parseFail(errorMsg)
    }
}
