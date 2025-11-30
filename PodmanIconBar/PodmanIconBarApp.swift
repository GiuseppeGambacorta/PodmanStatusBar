import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    var isVMRunning: Bool = false
    var podmanPath: String = "/opt/homebrew/bin/podman"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Trova il percorso di podman
        findPodmanPath()
        
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
        
        // Mostra i container solo se la VM è in esecuzione
        if isVMRunning {
            let containers = getRunningContainers()
            if containers.isEmpty {
                let item = NSMenuItem(title: "Nessun container in esecuzione", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                let containersTitle = NSMenuItem(title: "Container in esecuzione:", action: nil, keyEquivalent: "")
                containersTitle.isEnabled = false
                menu.addItem(containersTitle)
                
                for container in containers {
                    let item = NSMenuItem(title: "  \(container)", action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    menu.addItem(item)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
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
        task.launchPath = podmanPath
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
            isVMRunning = isRunning
            if let image = NSImage(named: imageName) {
                // Ridimensiona l'immagine per la menu bar (circa 18x18 punti)
                image.size = NSSize(width: 44, height: 22)
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
        task.launchPath = podmanPath
        task.arguments = args
        
        do {
            try task.run()
        } catch {
            print("Errore nell'esecuzione del comando: \(error)")
        }
    }
    
    func findPodmanPath() {
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["podman"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty {
                    podmanPath = path
                }
            }
        } catch {
            print("Errore nel trovare il percorso di podman: \(error)")
        }
    }
    
    func getRunningContainers() -> [String] {
        let task = Process()
        task.launchPath = podmanPath
        task.arguments = ["ps", "--format", "{{.Names}}"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        var containerNames: [String] = []
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                containerNames = output.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        } catch {
            print("Errore nel recupero dei container: \(error)")
        }
        
        return containerNames
    }
    
    @objc func quit() {
        timer?.invalidate()
        NSApplication.shared.terminate(self)
    }
}
