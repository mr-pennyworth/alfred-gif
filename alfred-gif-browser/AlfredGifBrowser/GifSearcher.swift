import Alamofire
import Alfred
import Foundation

let Limit = 50

struct GifSearchResult {
  let credits: String
  let gifs: [Gif]
}

struct Gif {
  let webURL: URL
  let title: String
}

struct Tenor {
  // Impersonate gboard
  static let url = "https://tenor.googleapis.com/v2/search"
  static let commonParams: [String: Codable] = [
    "key": "AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ",
    "client_key": "gboard",
    "limit": Limit,
  ]

  static func search(
    query: String,
    then callback: @escaping (GifSearchResult) -> ()
  ) {
    let format = "tinygif"
    let params = commonParams + [
      "media_filter": format,
      "q": query,
    ]
    AF.request(url, parameters: params)
      .responseDecodable(of: Response.self) { response in
        parse(response, format: format, then: callback)
      }
  }

  static func searchStickers(
    query: String,
    then callback: @escaping (GifSearchResult) -> ()
  ) {
    let format = "tinygif_transparent"
    let params = commonParams + [
      "searchfilter": "sticker",
      "media_filter": format,
      "q": query,
    ]
    AF.request(url, parameters: params)
      .responseDecodable(of: Response.self) { response in
        parse(response, format: format, then: callback)
      }
  }

  static func parse(
    _ response: DataResponse<Response, AFError>,
    format: String,
    then callback: @escaping (GifSearchResult) -> ()
  ) {
    log("Query URL: \(response.request!.url!)")
    if let resp: Response = response.value {
      let gifs: [Gif] = resp.results.map { result in
        let url = result.media_formats[format]!.url
        let title =
          (result.h1_title ?? makeTitle(from: url))
            .deleting(pattern: "( GIF| Sticker)")
        log("\(url)")
        return Gif(webURL: url, title: title)
      }
      callback(GifSearchResult(credits: "Powered by Tenor", gifs: gifs))
    } else {
      log("Error: couldn't parse: \(response)")
    }
  }

  static func makeTitle(from url: URL) -> String {
    url.path
      .split(separator: "/").last!
      .split(separator: ".")[0]
      .split(separator: "-")
      .map(\.capitalized)
      .joined(separator: " ")
  }

  struct Response: Codable {
    var results: [Result]

    struct Result: Codable {
      var h1_title: String?
      var media_formats: [String: Item]

      struct Item: Codable {
        var url: URL
      }
    }
  }
}


class Giphy {
  var key: String
  init(key: String) {
    self.key = key
  }

  func search(
    query: String,
    then callback: @escaping (GifSearchResult) -> ()
  ) {
    search(query, "gif", then: callback)
  }

  func searchStickers(
    query: String,
    then callback: @escaping (GifSearchResult) -> ()
  ) {
    search(query, "sticker", then: callback)
  }

  private func search(
    _ query: String,
    _ type: String,
    then callback: @escaping (GifSearchResult) -> ()
  ) {
    let url = "https://api.giphy.com/v1/\(type)s/search"
    let params: [String: Codable] = [
      "api_key": key,
      "limit": Limit,
      "q": query,
    ]
    AF.request(url, parameters: params)
      .responseDecodable(of: Response.self) { response in
        self.parse(response, then: callback)
      }
  }

  func parse(
    _ response: DataResponse<Response, AFError>,
    then callback: @escaping (GifSearchResult) -> ()
  ) {
    log("Query URL: \(response.request!.url!)")
    if let resp: Response = response.value {
      let gifs: [Gif] = resp.data.map { result in
        let url = URL(string: "https://i.giphy.com/\(result.id).gif")!
        log("\(url)")
        return Gif(webURL: url, title: result.title)
      }
      callback(GifSearchResult(credits: "Powered by GIPHY", gifs: gifs))
    } else {
      log("Error: couldn't parse: \(response)")
    }
  }

  struct Response: Codable {
    var data: [Item]

    struct Item: Codable {
      var title: String
      var type: String
      var id: String
    }
  }
}

/// Merge two dicts with the right one
/// taking precedence in case of key collision
func +<Key, Value> (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value] {
  lhs.merging(rhs){ $1 }
}
