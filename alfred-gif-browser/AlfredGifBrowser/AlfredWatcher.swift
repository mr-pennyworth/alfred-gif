import Alfred
import Cocoa
import CoreFoundation

typealias Dict = [String: Any]

class AlfredWatcher {
  var onDestroy: (() -> Void)!
  var onDownArrow: (() -> Void)!
  var onUpArrow: (() -> Void)!
  var onRightArrow: (() -> Void)!
  var onLeftArrow: (() -> Void)!
  var setAlfredFrame: ((NSRect)-> Void)!

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
    onLeftArrowPressed: @escaping () -> Void,
    setAlfredFrame: @escaping (NSRect) -> Void
  ) {
    PressSecretary.enable()

    onDestroy = onAlfredWindowDestroy
    onDownArrow = onDownArrowPressed
    onUpArrow = onUpArrowPressed
    onRightArrow = onRightArrowPressed
    onLeftArrow = onLeftArrowPressed
    self.setAlfredFrame = setAlfredFrame

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

    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(handleAlfredNotification),
      name: NSNotification.Name(rawValue: "alfred.presssecretary"),
      object: nil,
      suspensionBehavior: .deliverImmediately
    )
  }

  @objc func handleAlfredNotification(notification: NSNotification) {
    // log("\(notification)")
    let notif = notification.userInfo! as! Dict
    let notifType = notif["announcement"] as! String
    if (notifType == "window.hidden") {
      onDestroy()
    } else if (notifType == "selection.changed") {
      let frame = NSRectFromString(notif["windowframe"] as! String)
      setAlfredFrame(frame)
    }
  }
}
