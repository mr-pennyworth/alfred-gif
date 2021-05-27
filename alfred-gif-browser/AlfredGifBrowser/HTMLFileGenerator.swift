import Alfred
import Foundation

struct HTMLFileGenerator {
  var fileNamePrefix: String

  private func fileName(from searchQuery: String) -> String {
    let sep = "-"

    let sanitized =
      searchQuery
        .deleting(pattern: "[^0-9a-zA-Z ]")
        .split(separator: " ")
        .joined(separator: sep)

    return "\(fileNamePrefix)\(sep)\(sanitized).html"
  }

  func filePath(from searchQuery: String) -> URL {
    Workflow.cacheDir/fileName(from: searchQuery)
  }

  private static let smoothScrollJS: String =
    try! String(contentsOf: Workflow.dir/"smoothscroll.js")

  private static let gifBrowserJS: String =
    try! String(contentsOf: Workflow.dir/"gif-browser.js")

  private static let gifBrowserCSS: String =
    try! String(contentsOf: Workflow.dir/"gif-browser.css")

  func html(
    for searchResult: GifSearchResult,
    columnCount: Int = 3
  ) -> String {
    var cols: [[String]] = [[String]](repeating: [], count: columnCount)
    for (i, gif) in searchResult.gifs.enumerated() {
      cols[i % columnCount].append(
        "<img class='cell' src='\(gif.webURL)' title='\(gif.title)'>"
      )
    }

    let grid = cols.map {"""
      <div class='column'>
        \($0.joined(separator: "\n  "))
      </div>
      """
    }.joined(separator: "\n")

    return """
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <script>\(HTMLFileGenerator.smoothScrollJS)</script>
        <script>\(HTMLFileGenerator.gifBrowserJS)</script>
        <style>\(HTMLFileGenerator.gifBrowserCSS)</style>
        <style>\(Alfred.themeCSS)</style>
      </head>
      <body>
        \(grid)
        <footer>
          <span id="caption"></span>
          <span id="credits">\(searchResult.credits)</span>
        </footer>
      </body>
    </html>
    """
  }
}

extension String {
  func deleting(pattern: String) -> String {
    let str = NSMutableString(string: self)
    let regex = try? NSRegularExpression(pattern: pattern)
    regex?.replaceMatches(
      in: str,
      options: [],
      range: NSRange(location: 0, length: str.length),
      withTemplate: ""
    )
    return String(str)
  }
}
