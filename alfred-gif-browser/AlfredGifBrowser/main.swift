import AppKit
import Carbon
import Foundation
import WebKit


class GifDraggerWebView: WKWebView, NSDraggingSource {
  var selectedGif: URL!

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .copy
  }


  override func mouseDragged(with event: NSEvent) {
    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setData(selectedGif.dataRepresentation, forType: .fileURL)

    let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
    draggingItem.setDraggingFrame(self.bounds, contents: nil)

    self.beginDraggingSession(
      with: [draggingItem],
      event: event,
      source: self
    )
  }
}

// Floating webview based on: https://github.com/Qusic/Loaf
class AppDelegate: NSObject, NSApplicationDelegate {
  var minHeight: CGFloat = 600
  let maxWebviewWidth: CGFloat = 300

  let screen: NSScreen = NSScreen.main!
  lazy var screenWidth: CGFloat = screen.frame.width
  lazy var screenHeight: CGFloat = screen.frame.height

  let gifCacheDir: URL =
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library")
      .appendingPathComponent("Caches")
      .appendingPathComponent("com.runningwithcrayons.Alfred")
      .appendingPathComponent("Workflow Data")
      .appendingPathComponent("mr.pennyworth.gif")

  lazy var selectedGif: URL = gifCacheDir.appendingPathComponent("selected.gif")
  var selectedGifWebUrl: String = ""

  var urls: [URL?] = []
  var urlIdx = 0
  var css = ""

  let alfredWatcher: AlfredWatcher = AlfredWatcher()

  lazy var window: NSWindow = {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: [.borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false,
      screen: screen)
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

    // weird: without the following line
    // the webview just doesn't load!
    window.titlebarAppearsTransparent = true

    // Need this backgrund view gimickry because
    // if we don't have .titled for the window, window.backgroundColor seems to
    // have no effect at all, and we don't want titled because we don't want window
    // border
    let windowBkg = NSView(frame: NSRect.init())
    windowBkg.backgroundColor = NSColor.fromHexString(hex: "#1d1e28", alpha: 1)
    window.contentView = windowBkg

    return window
  }()

  lazy var webview: WKWebView = {
    let configuration = WKWebViewConfiguration()
    configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
    let webview = GifDraggerWebView(frame: .zero, configuration: configuration)
    webview.selectedGif = selectedGif
    return webview
  }()

  func setUrls(_ urlListJsonString: String) {
    self.urlIdx = 0
    let data = Data(urlListJsonString.utf8)
    do {
      let array = try JSONSerialization.jsonObject(with: data) as! [String]

      // empty strings map to file URL equivalent to "./",
      // which we later on decide to not render in render()
      self.urls = array.map({ path in
        if (path.starts(with: "/")) {
          return URL(fileURLWithPath: path)
        } else {
          return URL(string: path)
        }
      })
      render()
      // puzzler: why would the following cause a SEGFAULT?
      //          that too never while running in xcode
      // log("urls: \(self.urls)")
    } catch {
      log("Error: \(error)")
    }
  }

  func mouseAtInWebviewViewport(x: CGFloat, y: CGFloat) {
    if (!self.window.isVisible) {
      return
    }
    let wv = self.webview.frame
    if (x < 0 || x > wv.width || y < 0 || y > wv.height) {
      return
    }
    self.webview.evaluateJavaScript(
      "activateAtCoords(\(x), \(y))",
      completionHandler: { (out, err) in
        if let gifUrl = out {
          self.gifWithUrlChosen("\(gifUrl)")
        }
        // log("\(out)")
        // log("\(err)")
      })
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // The following mouse events take some time to start firing: why??
    NSEvent.addGlobalMonitorForEvents(
      matching: [NSEvent.EventTypeMask.mouseMoved],
      handler: { (event: NSEvent) in
        let mouse = event.locationInWindow
        let win = self.window.frame
        let wv = self.webview.frame
        // apple coords are from bottom left,
        // inside the webview, in the web world,
        // they are from top left
        self.mouseAtInWebviewViewport(
          x: mouse.x - (win.minX + wv.minX),
          y: (win.minY + wv.minY + wv.height) - mouse.y
        )
      }
    )

    window.contentView?.addSubview(webview)
    alfredWatcher.start(
      onAlfredWindowDestroy: {
        self.urls = [nil]
        let modifiers = self.alfredWatcher.mods
        if (modifiers.contains(.command)) {
          let pb = NSPasteboard.general
          pb.clearContents()
          pb.declareTypes([.fileContents], owner: nil)
          pb.writeObjects([self.selectedGif as NSURL])
        } else if (modifiers.contains(.option)) {
          log(self.selectedGifWebUrl)
          let pb = NSPasteboard.general
          pb.clearContents()
          pb.setString(self.selectedGifWebUrl, forType: .string)
        }
        self.window.orderOut(self)
      },
      onDownArrowPressed: self.makeBrowseFunction("down"),
      onUpArrowPressed: self.makeBrowseFunction("up"),
      onRightArrowPressed: self.makeBrowseFunction("right"),
      onLeftArrowPressed: self.makeBrowseFunction("left")
    )
  }

  func gifWithUrlChosen(_ gifUrl: String) {
    // Example gif url:
    // "https://media.tenor.com/images/f4c8059e75d21aa301174d4374ec4680/tenor.gif"
    self.selectedGifWebUrl = gifUrl
    let gifId = gifUrl.split(separator: "/")[3]
    let gifPath = self.gifCacheDir.appendingPathComponent("\(gifId).gif")
    let selected = self.gifCacheDir.appendingPathComponent("selected.gif")

    let cp = Process()
    cp.launchPath = "/bin/cp"
    cp.arguments = [gifPath.path, selected.path]
    cp.launch()
  }

  func makeBrowseFunction(_ jsFuncName: String) -> () -> () {
    func gifBrowser() {
      if (!self.window.isVisible) {
        return
      }
      self.webview.evaluateJavaScript(
        "\(jsFuncName)()",
        completionHandler: { (out, err) in
          if let gifUrl = out {
            self.gifWithUrlChosen("\(gifUrl)")
          }
          // log("\(out)")
          // log("\(err)")
        })
    }
    return gifBrowser
  }

  func showWindow(alfred: CGRect) {
    window.setFrame(
      NSRect(
        x: alfred.minX,
        y: alfred.maxY - minHeight,
        width: alfred.width,
        height: minHeight),
      display: false
    )
    webview.setFrameOrigin(NSPoint(x: 0, y: 0))
    webview.setFrameSize(NSSize(width: alfred.width, height: minHeight - alfred.height))
    window.makeKeyAndOrderFront(self)
  }

  func injectCSS(_ html: String) -> String {
    var cssContainer = "body"
    if html.contains("</head>") {
      cssContainer = "head"
    }
    return html.replacingOccurrences(
      of: "</\(cssContainer)>",
      with: "<style>\n\(self.css)</style></\(cssContainer)>"
    )
  }

  func injectCSS(fileUrl: URL) -> URL {
    // if you load html into webview using loadHTMLString,
    // the resultant webview can't be given access to filesystem
    // that means all the css and js references won't resolve anymore
    let injectedHtmlPath = fileUrl.path + ".injected.html"
    let injectedHtmlUrl = URL(fileURLWithPath: injectedHtmlPath)
    let injectedHtml = readFile(named: fileUrl.path, then: injectCSS)!
    try! injectedHtml.write(to: injectedHtmlUrl, atomically: true, encoding: .utf8)
    return injectedHtmlUrl
  }

  func render() {
    if (self.urls.count == 0 || self.urls == [nil]) {
      return
    }

    if let alfredFrame = self.alfredWatcher.alfredFrame() {
      self.urlIdx = (self.urlIdx + self.urls.count) % self.urls.count
      if let url = self.urls[self.urlIdx] {
        log("Rendering URL at index: \(self.urlIdx): \(url)")
        if (url.isFileURL) {
          webview.loadFileURL(
            injectCSS(fileUrl: url),
            allowingReadAccessTo: url.deletingLastPathComponent()
          )
        } else {
          webview.load(URLRequest(url: url))
        }
        webview.isHidden = false
        showWindow(alfred: alfredFrame)
      } else {
        log("Hiding as no URL was provided at index: \(self.urlIdx)")
        webview.isHidden = true
      }
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      log("\(url)")
      let param = url.queryParameters
      switch url.host {
      case "update":
        window.contentView?.backgroundColor = NSColor.fromHexString(
          hex: param["bkgColor"]!,
          alpha: 1
        )
        readFile(named: param["cssFile"]!, then: { css in self.css = css })
        readFile(named: param["specFile"]!, then: setUrls)
      default:
        break
      }
    }
  }
}


autoreleasepool {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.setActivationPolicy(.accessory)
  app.delegate = delegate
  app.run()
}
