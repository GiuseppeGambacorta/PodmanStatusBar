import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timerCheckStatus: Timer?
    var timerUpdateVmStateAtStartMachine : Timer?
    var isVMRunning: Bool = false
    var podmanPath: String = "/opt/homebrew/bin/podman"
    
    func applicationDidFinishLaunching(_ notification: Notification) {

        findPodmanPath()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        

        checkPodmanStatus()
        

        timerCheckStatus = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkPodmanStatus()
        }
    }
    
    @objc func statusItemClicked() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Check VM State", action: #selector(checkPodmanStatusManually), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        

        if isVMRunning {
            let containers = getRunningContainers()
            if containers.isEmpty {
                let item = NSMenuItem(title: "No container in execution", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                let containersTitle = NSMenuItem(title: "Container in execution:", action: nil, keyEquivalent: "")
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
        
        menu.addItem(NSMenuItem(title: "Start VM", action: #selector(startVM), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Stop VM", action: #selector(stopVM), keyEquivalent: "x"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Exit", action: #selector(quit), keyEquivalent: "q"))
        
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
            timerUpdateVmStateAtStartMachine?.invalidate()
            timerUpdateVmStateAtStartMachine = nil
            
            if isRunning {
                timerUpdateVmStateAtStartMachine = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    
                    self.isVMRunning = true
                    
                    if let image = NSImage(named: "podman-on") {
                        image.size = NSSize(width: 44, height: 22)
                        image.isTemplate = false
                        button.image = image
                    }
                    
                    button.toolTip = "Podman VM: active"
                }
            } else {
                
                self.isVMRunning = false
                
                if let image = NSImage(named: "podman-off") {
                    image.size = NSSize(width: 44, height: 22)
                    image.isTemplate = false
                    button.image = image
                }
                button.toolTip = "Podman VM: not active"
            }
            
          
        }
    }
    
    @objc func checkPodmanStatusManually() {
        checkPodmanStatus()
    }
    
    @objc func startVM() {
        statusItem?.menu?.cancelTracking()

        executeCommand(args: ["machine", "start"])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkPodmanStatus()
        }
    }
    
    @objc func stopVM() {
        statusItem?.menu?.cancelTracking()

        executeCommand(args: ["machine", "stop"])
        
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
            print("Error in command execution: \(error)")
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
            print("Error in podman path: \(error)")
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
            print("Error in container search: \(error)")
        }
        
        return containerNames
    }
    
    @objc func quit() {
        timerCheckStatus?.invalidate()
        NSApplication.shared.terminate(self)
    }
}
