import Alfred
import AppKit
import Foundation

extension NSView {
  var backgroundColor: NSColor? {
    get {
      guard let color = layer?.backgroundColor else {
        return nil
      }
      return NSColor(cgColor: color)
    }
    set {
      wantsLayer = true
      layer?.backgroundColor = newValue?.cgColor
    }
  }
}


func readFile<T>(named: String, then: (String) -> T) -> T? {
  if let fileContents = try? String(contentsOfFile: named, encoding: .utf8) {
    return then(fileContents)
  } else {
    log("Failed to read file: \(named)")
    return nil
  }
}

extension URL {
  // src: https://stackoverflow.com/a/26406426
  var queryParameters: QueryParameters {
    QueryParameters(url: self)
  }

  func parentDirName() -> String {
    pathComponents.get(-2)
  }

  func endsWith(_ suffix: String) -> Bool {
    path.hasSuffix(suffix)
  }

  func exists() -> Bool {
    FileManager.default.fileExists(atPath: path)
  }
}

class QueryParameters {
  let queryItems: [URLQueryItem]

  init(url: URL?) {
    queryItems = URLComponents(string: url?.absoluteString ?? "")?.queryItems ?? []
    print(queryItems)
  }

  subscript(name: String) -> String? {
    queryItems.first(where: { $0.name == name })?.value
  }
}

extension Array {
  func get(_ index: Int) -> Element {
    if index < 0 {
      return self[count + index]
    } else {
      return self[index]
    }
  }
}

extension Data {
  func asJsonObj() -> [String: Any]? {
    do {
      let parsedJson = try JSONSerialization.jsonObject(with: self)
      if let json = parsedJson as? [String: Any] {
        return json
      }
    } catch {
      log("\(error)")
      log("Error: Couldn't read JSON object from: \(self)")
    }
    return nil
  }
}
