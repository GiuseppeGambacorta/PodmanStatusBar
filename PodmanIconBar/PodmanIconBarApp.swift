import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Crea l'icona nella menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        // Controlla lo stato immediatamente
        checkPodmanStatus()
        
        // Controlla ogni 5 secondi
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkPodmanStatus()
        }
    }
    
    @objc func statusItemClicked() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Controlla stato", action: #selector(checkPodmanStatusManually), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Avvia VM", action: #selector(startVM), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Ferma VM", action: #selector(stopVM), keyEquivalent: "x"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Esci", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    func checkPodmanStatus() {
        let task = Process()
        task.launchPath = "/opt/homebrew/bin/podman"
        task.arguments = ["machine", "info", "--format", "json"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let host = json["Host"] as? [String: Any],
               let machineState = host["MachineState"] as? String {
                
                DispatchQueue.main.async {
                    self.updateStatus(isRunning: machineState.lowercased() == "running")
                }
            } else {
                DispatchQueue.main.async {
                    self.updateStatus(isRunning: false)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.updateStatus(isRunning: false)
            }
        }
    }
    
    func updateStatus(isRunning: Bool) {
        if let button = statusItem?.button {
            let imageName = isRunning ? "podman-on" : "podman-off"
            
            if let image = NSImage(named: imageName) {
                // Ridimensiona l'immagine per la menu bar (circa 18x18 punti)
                image.size = NSSize(width: 42, height: 20)
                image.isTemplate = false // Cambia a true se vuoi che l'immagine si adatti al tema (chiaro/scuro)
                button.image = image
            }
            
            button.toolTip = isRunning ? "Podman VM: in esecuzione" : "Podman VM: non attiva"
        }
    }
    
    @objc func checkPodmanStatusManually() {
        checkPodmanStatus()
    }
    
    @objc func startVM() {
        executeCommand(args: ["machine", "start"])
        // Aspetta un secondo e ricontrolla
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkPodmanStatus()
        }
    }
    
    @objc func stopVM() {
        executeCommand(args: ["machine", "stop"])
        // Aspetta un secondo e ricontrolla
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkPodmanStatus()
        }
    }
    
    func executeCommand(args: [String]) {
        let task = Process()
        task.launchPath = "/opt/homebrew/bin/podman"
        task.arguments = args
        
        do {
            try task.run()
        } catch {
            print("Errore nell'esecuzione del comando: \(error)")
        }
    }
    
    @objc func quit() {
        timer?.invalidate()
        NSApplication.shared.terminate(self)
    }
}
