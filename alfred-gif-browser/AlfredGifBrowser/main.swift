import Alfred
import AppKit
import Carbon
import Foundation
import WebKit


public let Port = 9911
public let Workflow = Alfred.workflow(id: "mr.pennyworth.gif")!

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
    draggingItem.setDraggingFrame(
      bounds,
      contents: NSImage.init(contentsOf: selectedGif)
    )

    beginDraggingSession(
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

  let webViewCache: WebViewCache = WebViewCache()
  var alfredFrame: NSRect = NSRect()
  let gifCacheDir: URL =
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library")
      .appendingPathComponent("Caches")
      .appendingPathComponent("com.runningwithcrayons.Alfred")
      .appendingPathComponent("Workflow Data")
      .appendingPathComponent("mr.pennyworth.gif")

  var selectedGifWebUrl: String = ""

  var url: URL? = nil

  let alfredWatcher: AlfredWatcher = AlfredWatcher()
  lazy var workflowServer: GifWorkflowServer = {
    GifWorkflowServer(port: Port, callback: self.setUrl)
  }()

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
    var bkgColor = "#1d1e28"
    if let bkgHexWithAlpha = Alfred.theme["window-color"] as? String {
      let bkgHexNoAlpha = String(bkgHexWithAlpha.dropLast(2))
      bkgColor = bkgHexNoAlpha
    }
    windowBkg.backgroundColor = NSColor.fromHexString(hex: bkgColor, alpha: 1)

    window.contentView = windowBkg

    return window
  }()

  lazy var webview: GifDraggerWebView = {
    let configuration = WKWebViewConfiguration()
    configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
    let webview = GifDraggerWebView(frame: .zero, configuration: configuration)
    webview.selectedGif = gifCacheDir.appendingPathComponent("selected.gif")
    return webview
  }()

  func setUrl(_ htmlPath: URL) {
    url = htmlPath
    render()
  }

  func mouseAtInWebviewViewport(x: CGFloat, y: CGFloat) {
    if (!window.isVisible) {
      return
    }
    let wv = webview.frame
    if (x < 0 || x > wv.width || y < 0 || y > wv.height) {
      return
    }
    webview.evaluateJavaScript(
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
        if (self.window.isVisible) {
          self.url = nil
          let modifiers = self.alfredWatcher.mods
          if (modifiers.contains(.command)) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.declareTypes([.fileContents], owner: nil)
            pb.writeObjects([self.webview.selectedGif as NSURL])
          } else if (modifiers.contains(.option)) {
            log(self.selectedGifWebUrl)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(self.selectedGifWebUrl, forType: .string)
          }
          self.window.orderOut(self)
        }
      },
      onDownArrowPressed: makeBrowseFunction("down"),
      onUpArrowPressed: makeBrowseFunction("up"),
      onRightArrowPressed: makeBrowseFunction("right"),
      onLeftArrowPressed: makeBrowseFunction("left"),
      setAlfredFrame: { self.alfredFrame = $0 }
    )
    workflowServer.start()
  }

  func gifWithUrlChosen(_ gifUrl: String) {
    selectedGifWebUrl = gifUrl
    if let webURL = URL(string: gifUrl) {
      if let gifPath = webViewCache[webURL] {
        // FileManager.copyItem and replaceItem are finicky
        // as they expect proper error handling.
        // Instead, just launch the "cp" program.
        let cp = Process()
        cp.launchPath = "/bin/cp"
        cp.arguments = [gifPath.path, webview.selectedGif.path]
        cp.launch()
      } else {
        log("Gif \(gifUrl) not yet downloaded.")
      }
    } else {
      log("Invalid URL: \(gifUrl)")
    }
  }

  func makeBrowseFunction(_ jsFuncName: String) -> () -> () {
    func gifBrowser() {
      if (!window.isVisible) {
        return
      }
      webview.evaluateJavaScript(
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
      with: "<style>\n\(Alfred.themeCSS)</style></\(cssContainer)>"
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
    if let url = url {
      webview.loadFileURL(
        injectCSS(fileUrl: url),
        allowingReadAccessTo: url.deletingLastPathComponent()
      )
      showWindow(alfred: alfredFrame)
    } else {
      window.orderOut(self)
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
