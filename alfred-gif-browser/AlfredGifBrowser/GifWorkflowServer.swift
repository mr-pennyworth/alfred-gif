import Alfred
import Foundation

enum GifSearchService: String {
  case tenor, sticker
}

class GifScriptFilter: AsyncScriptFilter {
  private let gifBrowserCallback: (URL) -> ()
  init(_ gifBrowserCallback: @escaping (URL) -> ()) {
    self.gifBrowserCallback = gifBrowserCallback
  }
  func process(
    query: [String: String],
    then: @escaping (ScriptFilterResponse) -> ()
  ) {
    let searchStr = query["query"]!
    let service = GifSearchService(rawValue: query["service"]!)!

    // can not specify type of this
    // because type signature can't have @escaping
    // and if we omit it, it simply won't match to
    // either Tenor.search or Tenor.searchStickers
    var searcher = Tenor.search

    switch service {
    case .tenor: searcher = Tenor.search
    case .sticker: searcher = Tenor.searchStickers
    }

    let htmlGen = HTMLFileGenerator(fileNamePrefix: service.rawValue)
    searcher(searchStr) { gifSearchResult in
      let htmlFilePath = htmlGen.filePath(from: searchStr)
      let html = htmlGen.html(for: gifSearchResult)
      try! html.write(to: htmlFilePath, atomically: true, encoding: .utf8)
      then(ScriptFilterResponse(items: [.item(
        arg: "dummy",
        title: "Select with arrow keys, drag-n-drop with mouse",
        subtitle: "[↩: search again] [⌘: copy GIF] [⌥: copy URL]")])
      )
      self.gifBrowserCallback(htmlFilePath)
    }
  }
}

class GifWorkflowServer {
  private var server: ScriptFilterServer

  init(
    port: Int,
    callback gifBrowserCallback: @escaping (URL) -> ()
  ) {
    let filter = GifScriptFilter(gifBrowserCallback)
    server = ScriptFilterServer(
      port: port,
      handler: .from(filter)
    )
  }

  func start() {
    server.start()
  }
}
