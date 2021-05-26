import Alfred
import FileWatcher
import Foundation

class WebViewCache {
  private var webUrl2FileUrl: [URL: URL] = [URL: URL]()

  private let cacheDir: URL =
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library")
      .appendingPathComponent("Caches")
      .appendingPathComponent(Bundle.main.bundleIdentifier!)
      .appendingPathComponent("WebKit")
      .appendingPathComponent("NetworkCache")

  private func extractWebURL(cacheRecordURL: URL) throws -> URL {
    let fileHandle = try FileHandle(forReadingFrom: cacheRecordURL)

    // 22nd byte in the file denotes the length of the web URL
    fileHandle.seek(toFileOffset: 22)
    let webURLLen: UInt8 = [UInt8](fileHandle.readData(ofLength: 1))[0]

    // 27th byte is where the web URL begins
    fileHandle.seek(toFileOffset: 27)
    let webURLData = fileHandle.readData(ofLength: Int(webURLLen))

    fileHandle.closeFile()
    return URL(string: String(data: webURLData, encoding: .utf8)!)!
  }

  private func isRecordFile(url: URL) -> Bool {
    url.parentDirName() == "Resource" && !url.endsWith("-blob")
  }

  private func addToDict(recordFileURL: URL) {
    do {
      let webURL = try extractWebURL(cacheRecordURL: recordFileURL)
      log("Web URL in cache: \(webURL)")

      let blobPath = recordFileURL.path.appending("-blob")
      if FileManager.default.fileExists(atPath: blobPath) {
        let blobURL = URL(fileURLWithPath: blobPath)
        webUrl2FileUrl[webURL] = blobURL
        log("Cache dict size: \(webUrl2FileUrl.count)")
      } else {
        log("Blob for \(webURL) doesn't exist at \(blobPath)")
      }
    } catch {
      log("\(error)")
    }
  }

  private func processExistingCache() {
    if let enumerator = FileManager.default.enumerator(
      at: cacheDir,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) {
      for case let fileURL as URL in enumerator {
        if isRecordFile(url: fileURL) {
          addToDict(recordFileURL: fileURL)
        }
      }
      log("Processed existing WebKit cache: \(webUrl2FileUrl.count) entries.")
      log("\(webUrl2FileUrl)")
    } else {
      log("Could not enumerate directory \(cacheDir.path).")
    }
  }

  private func startCacheDirWatcher() {
    let fileWatcher = FileWatcher([cacheDir.path])

    fileWatcher.callback = { event in
      if (event.fileCreated && event.fileModified) {
        let url = URL(fileURLWithPath: event.path)
        if self.isRecordFile(url: url) {
          let filename = url.pathComponents.get(-1)
          log("Adding to cache due to FS change: \(filename))")
          self.addToDict(recordFileURL: url)
        }
      }
    }

    fileWatcher.queue = DispatchQueue.global(qos: .userInteractive)
    fileWatcher.start()
  }

  init() {
    processExistingCache()
    startCacheDirWatcher()
  }

  subscript(webURL: URL) -> URL? {
    webUrl2FileUrl[webURL]
  }
}
