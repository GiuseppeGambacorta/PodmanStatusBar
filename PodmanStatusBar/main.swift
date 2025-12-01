
import Cocoa


UserDefaults.standard.set(true, forKey: "LSUIElement")


let application = NSApplication.shared


let delegate = AppDelegate()
application.delegate = delegate


application.run()
