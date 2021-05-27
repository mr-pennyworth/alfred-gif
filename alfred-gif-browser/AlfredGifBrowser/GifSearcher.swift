import Alamofire
import Alfred
import Foundation

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
    "limit": 50,
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


/// Merge two dicts with the right one
/// taking precedence in case of key collision
func +<Key, Value> (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value] {
  lhs.merging(rhs){ $1 }
}
