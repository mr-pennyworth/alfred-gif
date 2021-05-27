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

class Tenor {
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
    AF.request(url, parameters: params).responseData { resp in
      log("Query URL: \(resp.request!.url!)")
      if let json = resp.data?.asJsonObj() {
        parseJson(json: json, format: format, then: callback)
      }
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
    AF.request(url, parameters: params).responseData { resp in
      log("Query URL: \(resp.request!.url!)")
      if let json = resp.data?.asJsonObj() {
        parseJson(json: json, format: format, then: callback)
      }
    }
  }

  static func parseJson(
    json: [String: Any],
    format: String,
    then: (GifSearchResult) -> ()
  ) {
    let gifs: [Gif] =
      (json["results"] as! [[String: Any]])
        .map { $0["media_formats"] as! [String: Any] }
        .map { $0[format] as! [String: Any] }
        .map { $0["url"] as! String }
        .map { url in
          let webURL = URL(string: url)!
          let title: String =
            url
              .split(separator: "/").last!
              .split(separator: ".")[0]
              .split(separator: "-")
              .map(\.capitalized)
              .joined(separator: " ")
          log("\(url)")
          return Gif(webURL: webURL, title: title)
        }
    then(GifSearchResult(credits: "Powered by Tenor", gifs: gifs))
  }
}


/// Merge two dicts with the right one
/// taking precedence in case of key collision
func +<Key, Value> (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value] {
  lhs.merging(rhs){ $1 }
}
