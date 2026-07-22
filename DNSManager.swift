import Foundation
import AppKit

enum DNSMode {
    case stream
    case normal
    case unknown
}

enum PrivateRelayStatus: String {
    case active = "ON (Active)"
    case paused = "PAUSED"
    case off = "OFF"
    case unknown = "Checking..."
}

class DNSManager: ObservableObject {
    static let smartDNSIPs = ["35.178.60.174", "45.77.61.165"]
    
    @Published var wifiInterface: String = "Wi-Fi"
    @Published var currentDNS: [String] = []
    @Published var currentMode: DNSMode = .unknown
    @Published var relayStatus: PrivateRelayStatus = .unknown
    @Published var isUpdating: Bool = false
    @Published var lastMessage: String? = nil
    
    private var refreshTimer: Timer?
    
    init() {
        refresh()
        setupNotificationObservers()
        startAutoRefresh()
    }
    
    deinit {
        stopAutoRefresh()
    }
    
    func startAutoRefresh() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidBecomeActive() {
        refresh()
    }
    
    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let interface = self?.detectWiFiInterface() ?? "Wi-Fi"
            let dnsServers = self?.fetchDNSServers(interface: interface) ?? []
            let relay = self?.fetchPrivateRelayStatus() ?? .off
            
            let isStream = dnsServers.contains(where: { DNSManager.smartDNSIPs.contains($0) })
            let mode: DNSMode = isStream ? .stream : .normal
            
            DispatchQueue.main.async {
                self?.wifiInterface = interface
                self?.currentDNS = dnsServers
                self?.currentMode = mode
                self?.relayStatus = relay
            }
        }
    }
    
    func switchMode(to targetMode: DNSMode, completion: ((Bool) -> Void)? = nil) {
        isUpdating = true
        lastMessage = "Applying DNS changes..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let interface = self.wifiInterface
            let dnsArgs: String
            if targetMode == .stream {
                dnsArgs = DNSManager.smartDNSIPs.joined(separator: " ")
            } else {
                dnsArgs = "Empty"
            }
            
            let command = "networksetup -setdnsservers '\(interface)' \(dnsArgs) && dscacheutil -flushcache && killall -HUP mDNSResponder"
            let appleScriptSource = "do shell script \"\(command)\" with administrator privileges"
            
            var errorDict: NSDictionary?
            let appleScript = NSAppleScript(source: appleScriptSource)
            let result = appleScript?.executeAndReturnError(&errorDict)
            
            let success = (result != nil && errorDict == nil)
            
            DispatchQueue.main.async {
                self.isUpdating = false
                if success {
                    self.lastMessage = "DNS updated successfully!"
                    self.refresh()
                    
                    // Manage relay guidance
                    if targetMode == .stream && self.relayStatus == .active {
                        self.openPrivateRelaySettings()
                    } else if targetMode == .normal && (self.relayStatus == .off || self.relayStatus == .paused) {
                        self.openPrivateRelaySettings()
                    }
                } else {
                    let errMsg = errorDict?[NSAppleScript.errorMessage] as? String ?? "Authorization cancelled or failed."
                    self.lastMessage = "Error: \(errMsg)"
                }
                completion?(success)
            }
        }
    }
    
    func flushDNSCache(completion: ((Bool) -> Void)? = nil) {
        isUpdating = true
        lastMessage = "Flushing DNS cache..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let command = "dscacheutil -flushcache && killall -HUP mDNSResponder"
            let appleScriptSource = "do shell script \"\(command)\" with administrator privileges"
            
            var errorDict: NSDictionary?
            let appleScript = NSAppleScript(source: appleScriptSource)
            let result = appleScript?.executeAndReturnError(&errorDict)
            let success = (result != nil && errorDict == nil)
            
            DispatchQueue.main.async {
                self?.isUpdating = false
                self?.lastMessage = success ? "DNS cache flushed!" : "Flush cache cancelled/failed."
                completion?(success)
            }
        }
    }
    
    func openPrivateRelaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?email/prefs/accountDetails?path=InternetPrivacy") {
            NSWorkspace.shared.open(url)
        }
        for delay in [1.0, 3.0, 5.0, 8.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refresh()
            }
        }
    }
    
    func openSmartDNSAccount() {
        if let url = URL(string: "https://www.smartdnsproxy.com/MyAccount") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Helper Methods
    
    private func detectWiFiInterface() -> String {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listallnetworkservices"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.localizedCaseInsensitiveContains("wi-fi") || trimmed.localizedCaseInsensitiveContains("airport") {
                        return trimmed
                    }
                }
            }
        } catch {}
        return "Wi-Fi"
    }
    
    private func fetchDNSServers(interface: String) -> [String] {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getdnsservers", interface]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return lines
            }
        } catch {}
        return []
    }
    
    private func fetchPrivateRelayStatus() -> PrivateRelayStatus {
        let pythonScript = """
import plistlib, subprocess

def get_nested_val(val, objects):
    if isinstance(val, plistlib.UID):
        return get_nested_val(objects[val.data], objects)
    elif isinstance(val, dict):
        return {k: get_nested_val(v, objects) for k, v in val.items() if k != "$class"}
    elif isinstance(val, list):
        return [get_nested_val(v, objects) for v in val]
    return val

status = "OFF"
try:
    res = subprocess.run(["defaults", "export", "com.apple.networkserviceproxy", "-"], capture_output=True)
    if res.returncode == 0:
        data = plistlib.loads(res.stdout)
        if "NSPServiceStatusManagerInfo" in data:
            status_info = plistlib.loads(data["NSPServiceStatusManagerInfo"])
            objects = status_info.get("$objects", [])
            top = status_info.get("$top", {})
            if "ServiceStatus" in top:
                service_status = get_nested_val(top["ServiceStatus"], objects)
                global_status = service_status.get("PrivacyProxyServiceStatus")
                if global_status == 1:
                    status = "ON (Active)"
                    net_statuses = service_status.get("PrivacyProxyNetworkStatuses", {}).get("NS.objects", [])
                    for ns in net_statuses:
                        if ns.get("PrivacyProxyNetworkStatus") != 1:
                            status = "PAUSED"
                            break
                elif global_status == 2:
                    status = "PAUSED"
                else:
                    status = "OFF"
except:
    status = "OFF"
print(status)
"""
        
        let task = Process()
        task.launchPath = "/usr/bin/python3"
        task.arguments = ["-c", pythonScript]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if output.contains("ON (Active)") {
                    return .active
                } else if output.contains("PAUSED") {
                    return .paused
                } else {
                    return .off
                }
            }
        } catch {}
        return .off
    }
}
