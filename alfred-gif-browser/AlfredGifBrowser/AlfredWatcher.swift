import AXSwift
import Cocoa
import Swindler
import PromiseKit
import CoreFoundation


class AlfredWatcher {
  var swindler: Swindler.State!
  var onDestroy: (() -> Void)!
  var onDownArrow: (() -> Void)!
  var onUpArrow: (() -> Void)!
  var onRightArrow: (() -> Void)!
  var onLeftArrow: (() -> Void)!

  var mods: NSEvent.ModifierFlags = NSEvent.ModifierFlags()

  let LEFT_ARROW: UInt16 = 123
  let RIGHT_ARROW: UInt16 = 124
  let DOWN_ARROW: UInt16 = 125
  let UP_ARROW: UInt16 = 126

  func start(
    onAlfredWindowDestroy: @escaping () -> Void,
    onDownArrowPressed: @escaping () -> Void,
    onUpArrowPressed: @escaping () -> Void,
    onRightArrowPressed: @escaping () -> Void,
    onLeftArrowPressed: @escaping () -> Void
  ) {
    self.onDestroy = onAlfredWindowDestroy
    self.onDownArrow = onDownArrowPressed
    self.onUpArrow = onUpArrowPressed
    self.onRightArrow = onRightArrowPressed
    self.onLeftArrow = onLeftArrowPressed

    guard AXSwift.checkIsProcessTrusted(prompt: true) else {
      NSLog("Not trusted as an AX process; please authorize and re-launch")
      NSApp.terminate(self)
      return
    }

    Swindler.initialize().done { state in
      self.swindler = state
      self.setupEventHandlers()
    }.catch { error in
      NSLog("Fatal error: failed to initialize Swindler: \(error)")
      NSApp.terminate(self)
    }

    NSEvent.addGlobalMonitorForEvents(
      matching: [NSEvent.EventTypeMask.keyDown],
      handler: { (event: NSEvent) in
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCtrl = (mods == [.control])
        let keyCode = event.keyCode
        let key = event.charactersIgnoringModifiers
        if (keyCode == self.UP_ARROW || (isCtrl && key == "p")) {
          self.onUpArrow()
        } else if (keyCode == self.DOWN_ARROW || (isCtrl && key == "n")) {
          self.onDownArrow()
        } else if (keyCode == self.LEFT_ARROW) {
          self.onLeftArrow()
        } else if (keyCode == self.RIGHT_ARROW) {
          self.onRightArrow()
        }
      }
    )

    NSEvent.addGlobalMonitorForEvents(
      matching: [NSEvent.EventTypeMask.flagsChanged],
      handler: { (event: NSEvent) in
        self.mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      }
    )
  }

  private func isAlfredWindow(window: Window) -> Bool {
    let bundle = window.application.bundleIdentifier ?? ""
    let title = window.title.value
    return (bundle == "com.runningwithcrayons.Alfred" && title == "Alfred")
  }

  private func setupEventHandlers() {
    swindler.on { (event: WindowDestroyedEvent) in
      if (self.isAlfredWindow(window: event.window)) {
        NSLog("Alfred window destroyed")
        self.onDestroy()
      }
    }
  }

  func alfredFrame() -> CGRect? {
    if (swindler == nil) {
      // when the application isn't already running, and the first call is
      // by invoking the app specific url, swindler might not have been
      // initialized by then. for that special case, we explicitly get
      // alfred frame without relying on swindler.
      let options = CGWindowListOption([.excludeDesktopElements, .optionOnScreenOnly])
      let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
      let wli = windowListInfo as NSArray? as? [[String: AnyObject]]
      if let alfredWindow = wli?.first(where: { windowInfo in
        if let name = windowInfo["kCGWindowOwnerName"] as? String {
          if (name == "Alfred") {
            return true
          } else {
            return false
          }
        } else {
          return false
        }
      }) {
        if let bounds = alfredWindow["kCGWindowBounds"] {
          let frame = CGRect.init(
            dictionaryRepresentation: bounds as! CFDictionary
          )
          log("Non-Swindler frame: \(String(describing: frame))")
          return frame
        }
      }

      return nil
    } else {
      let alfredWindow = swindler.knownWindows.first(where: self.isAlfredWindow)!
      let alfred = alfredWindow.frame
      return alfred.value
    }
  }
}
