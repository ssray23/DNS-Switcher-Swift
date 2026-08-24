import Foundation
import AppKit

enum DNSMode {
    case stream
    case fastBrowsing
    case normal
    case custom
    case unknown
}

enum PrivateRelayStatus: String {
    case active = "ON (Active)"
    case paused = "PAUSED"
    case off = "OFF"
    case unknown = "Checking..."
}

class DNSManager: ObservableObject {
    private static let primaryServerKey = "DNSManager_PrimaryServerId"
    private static let secondaryServerKey = "DNSManager_SecondaryServerId"
    private static let presetsKey = "DNSManager_PresetsKey_v2"
    private static let fastPresetKey = "DNSManager_SelectedFastPresetId"
    
    @Published var primaryServer: SmartDNSServer {
        didSet {
            UserDefaults.standard.set(primaryServer.id, forKey: DNSManager.primaryServerKey)
        }
    }
    
    @Published var secondaryServer: SmartDNSServer {
        didSet {
            UserDefaults.standard.set(secondaryServer.id, forKey: DNSManager.secondaryServerKey)
        }
    }
    
    @Published var presets: [ServerPairPreset] = []
    
    @Published var selectedFastPreset: FastDNSPreset {
        didSet {
            UserDefaults.standard.set(selectedFastPreset.id, forKey: DNSManager.fastPresetKey)
        }
    }
    
    var activeSmartDNSIPs: [String] {
        if primaryServer.ip == secondaryServer.ip {
            return [primaryServer.ip]
        }
        return [primaryServer.ip, secondaryServer.ip]
    }
    
    @Published var wifiInterface: String = "Wi-Fi"
    @Published var currentDNS: [String] = []
    @Published var currentMode: DNSMode = .unknown
    @Published var relayStatus: PrivateRelayStatus = .unknown
    @Published var isUpdating: Bool = false
    @Published var lastMessage: String? = nil
    
    // Benchmarking & Latency
    @Published var serverLatencies: [String: Int] = [:]
    @Published var isBenchmarking: Bool = false
    
    private var refreshTimer: Timer?
    
    init() {
        let primaryId = UserDefaults.standard.string(forKey: DNSManager.primaryServerKey) ?? "nl_amsterdam"
        let secondaryId = UserDefaults.standard.string(forKey: DNSManager.secondaryServerKey) ?? "kr_seoul"
        let fastId = UserDefaults.standard.string(forKey: DNSManager.fastPresetKey) ?? "cloudflare"
        
        self.primaryServer = SmartDNSCatalog.findServer(byId: primaryId) ?? SmartDNSCatalog.amsterdam
        self.secondaryServer = SmartDNSCatalog.findServer(byId: secondaryId) ?? SmartDNSCatalog.seoul
        self.selectedFastPreset = FastDNSCatalog.findPreset(byId: fastId) ?? FastDNSCatalog.cloudflare
        
        if let data = UserDefaults.standard.data(forKey: DNSManager.presetsKey),
           let saved = try? JSONDecoder().decode([ServerPairPreset].self, from: data),
           !saved.isEmpty {
            self.presets = saved
        } else {
            self.presets = SmartDNSCatalog.presets
        }
        
        refresh()
        setupNotificationObservers()
        startAutoRefresh()
    }
    
    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: DNSManager.presetsKey)
        }
    }
    
    func isPresetSaved(primary: SmartDNSServer, secondary: SmartDNSServer) -> Bool {
        presets.contains(where: { $0.primary == primary && $0.secondary == secondary })
    }
    
    func savePreset(primary: SmartDNSServer, secondary: SmartDNSServer, name: String? = nil) {
        if isPresetSaved(primary: primary, secondary: secondary) {
            return
        }
        let presetName = name ?? "\(primary.flag) \(primary.city) + \(secondary.flag) \(secondary.city)"
        let newPreset = ServerPairPreset(id: UUID().uuidString, name: presetName, primary: primary, secondary: secondary, isCustom: true)
        presets.append(newPreset)
        persistPresets()
    }
    
    func unsavePreset(primary: SmartDNSServer, secondary: SmartDNSServer) {
        presets.removeAll(where: { $0.primary == primary && $0.secondary == secondary })
        persistPresets()
    }
    
    func removePreset(byId id: String) {
        presets.removeAll(where: { $0.id == id })
        persistPresets()
    }
    
    deinit {
        stopAutoRefresh()
    }
    
    func updateServers(primary: SmartDNSServer, secondary: SmartDNSServer, applyImmediately: Bool = true) {
        self.primaryServer = primary
        self.secondaryServer = secondary
        
        if applyImmediately {
            switchMode(to: .stream)
        } else {
            refresh()
        }
    }
    
    func applyFastPreset(_ preset: FastDNSPreset, completion: ((Bool) -> Void)? = nil) {
        self.selectedFastPreset = preset
        switchMode(to: .fastBrowsing, fastPreset: preset, completion: completion)
    }
    
    func serverForIP(_ ip: String) -> SmartDNSServer? {
        SmartDNSCatalog.findServer(byIP: ip)
    }
    
    func fastPresetForIP(_ ip: String) -> FastDNSPreset? {
        FastDNSCatalog.provider(forIP: ip)
    }
    
    // MARK: - Latency & Benchmarking
    
    func latency(forIP ip: String) -> Int? {
        serverLatencies[ip]
    }
    
    func latency(forFastPreset preset: FastDNSPreset) -> Int? {
        serverLatencies[preset.primaryIP]
    }
    
    func latency(forServer server: SmartDNSServer) -> Int? {
        serverLatencies[server.ip]
    }
    
    func runBenchmark(completion: (() -> Void)? = nil) {
        guard !isBenchmarking else { return }
        isBenchmarking = true
        
        var allIPs = Set<String>()
        for preset in FastDNSCatalog.allPresets {
            allIPs.formUnion(preset.ips)
        }
        for server in SmartDNSCatalog.allServers {
            allIPs.insert(server.ip)
        }
        
        Task {
            let latencies = await DNSBenchmarkEngine.shared.probeAll(ips: Array(allIPs), timeoutSeconds: 1.5)
            await MainActor.run {
                self.serverLatencies = latencies
                self.isBenchmarking = false
                completion?()
            }
        }
    }
    
    @discardableResult
    func autoSelectFastestFastDNS() -> FastDNSPreset? {
        let tested = FastDNSCatalog.allPresets.compactMap { preset -> (FastDNSPreset, Int)? in
            guard let lat = latency(forFastPreset: preset) else { return nil }
            return (preset, lat)
        }
        guard let fastest = tested.min(by: { $0.1 < $1.1 })?.0 else {
            return nil
        }
        self.selectedFastPreset = fastest
        return fastest
    }
    
    @discardableResult
    func autoSelectFastestSmartDNSPair() -> (primary: SmartDNSServer, secondary: SmartDNSServer)? {
        let tested = SmartDNSCatalog.allServers.compactMap { server -> (SmartDNSServer, Int)? in
            guard let lat = latency(forServer: server) else { return nil }
            return (server, lat)
        }
        let sorted = tested.sorted(by: { $0.1 < $1.1 }).map { $0.0 }
        guard sorted.count >= 2 else {
            return nil
        }
        let bestPrimary = sorted[0]
        let bestSecondary = sorted[1]
        self.primaryServer = bestPrimary
        self.secondaryServer = bestSecondary
        return (bestPrimary, bestSecondary)
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
            guard let self = self else { return }
            let interface = self.detectWiFiInterface()
            let dnsServers = self.fetchDNSServers(interface: interface)
            let relay = self.fetchPrivateRelayStatus()
            
            let activeIPs = self.activeSmartDNSIPs
            let matchingFastPreset = FastDNSCatalog.findPreset(matchingIPs: dnsServers)
            
            let isStream = !dnsServers.isEmpty && (
                dnsServers.allSatisfy { activeIPs.contains($0) } ||
                dnsServers.allSatisfy { SmartDNSCatalog.findServer(byIP: $0) != nil }
            )
            let isFast = !dnsServers.isEmpty && matchingFastPreset != nil
            let isAutomatic = dnsServers.isEmpty
            
            let mode: DNSMode
            if isStream {
                mode = .stream
            } else if isFast {
                mode = .fastBrowsing
            } else if isAutomatic {
                mode = .normal
            } else {
                mode = .custom
            }
            
            DispatchQueue.main.async {
                self.wifiInterface = interface
                self.currentDNS = dnsServers
                self.currentMode = mode
                self.relayStatus = relay
                if let fast = matchingFastPreset {
                    self.selectedFastPreset = fast
                }
            }
        }
    }
    
    func switchMode(to targetMode: DNSMode, fastPreset: FastDNSPreset? = nil, completion: ((Bool) -> Void)? = nil) {
        if let preset = fastPreset {
            self.selectedFastPreset = preset
        }
        
        isUpdating = true
        lastMessage = "Applying DNS changes..."
        
        let presetToApply = fastPreset ?? self.selectedFastPreset
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let interface = self.wifiInterface
            let dnsArgs: String
            switch targetMode {
            case .stream:
                dnsArgs = self.activeSmartDNSIPs.joined(separator: " ")
            case .fastBrowsing:
                dnsArgs = presetToApply.ips.joined(separator: " ")
            case .normal:
                dnsArgs = "Empty"
            case .custom, .unknown:
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
                    .filter { !$0.isEmpty && !$0.contains("aren't any DNS Servers set") }
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
