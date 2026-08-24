import SwiftUI

struct ContentView: View {
    @ObservedObject var dnsManager: DNSManager
    @State private var showingSettings: Bool = false
    
    var body: some View {
        Group {
            if showingSettings {
                SettingsView(dnsManager: dnsManager) {
                    showingSettings = false
                }
            } else {
                mainView
            }
        }
        .onAppear {
            dnsManager.refresh()
            dnsManager.startAutoRefresh()
        }
        .onDisappear {
            dnsManager.stopAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            dnsManager.refresh()
        }
    }
    
    private var mainView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("DNS Switcher")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Server Settings")
                .padding(.trailing, 4)
                
                Button(action: {
                    dnsManager.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Refresh Status")
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Current Status Card
            VStack(alignment: .leading, spacing: 10) {
                // Interface & Mode
                HStack {
                    Text("Interface:")
                        .foregroundColor(.secondary)
                    Text(dnsManager.wifiInterface)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    modeBadgeView
                }
                
                // DNS IPs
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current DNS Servers:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if dnsManager.currentDNS.isEmpty {
                        Text("Automatic (DHCP / Router)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(dnsManager.currentDNS, id: \.self) { ip in
                            HStack {
                                Text(ip)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                
                                if let fastPreset = dnsManager.fastPresetForIP(ip) {
                                    Text("\(fastPreset.icon) \(fastPreset.name)")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(.purple)
                                        .cornerRadius(4)
                                } else if let server = dnsManager.serverForIP(ip) {
                                    Text("\(server.flag) \(server.city)")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                } else if dnsManager.activeSmartDNSIPs.contains(ip) {
                                    Text("SmartDNS")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                                
                                if let lat = dnsManager.latency(forIP: ip) {
                                    LatencyBadge(latency: lat)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // Private Relay Status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud Private Relay:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(dnsManager.relayStatus.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(relayColor(dnsManager.relayStatus))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dnsManager.openPrivateRelaySettings()
                    }) {
                        Text("Manage...")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Active Server Preset Target
            HStack {
                Text("Target:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if dnsManager.currentMode == .fastBrowsing {
                    Text("\(dnsManager.selectedFastPreset.icon) \(dnsManager.selectedFastPreset.name) (\(dnsManager.selectedFastPreset.formattedIPs))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("\(dnsManager.primaryServer.flag) \(dnsManager.primaryServer.city) + \(dnsManager.secondaryServer.flag) \(dnsManager.secondaryServer.city)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button("Configure...") {
                    showingSettings = true
                }
                .font(.caption2)
                .buttonStyle(.link)
            }
            .padding(.horizontal, 2)
            
            // Mode Control Buttons
            VStack(spacing: 7) {
                // 1. Fast Browsing Mode Button
                Button(action: {
                    dnsManager.switchMode(to: .fastBrowsing)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(dnsManager.currentMode == .fastBrowsing ? "In Fast Browsing (\(dnsManager.selectedFastPreset.name))" : "Switch to Fast Browsing (\(dnsManager.selectedFastPreset.name))")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        dnsManager.currentMode == .fastBrowsing 
                            ? Color.purple.opacity(0.55) 
                            : Color.purple
                    )
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .disabled(dnsManager.isUpdating || (dnsManager.currentMode == .fastBrowsing && dnsManager.currentDNS == dnsManager.selectedFastPreset.ips))
                
                // 2. Fast DNS Quick Switch Pills
                HStack(spacing: 5) {
                    ForEach(FastDNSCatalog.allPresets) { preset in
                        let isSelectedPreset = (dnsManager.selectedFastPreset.id == preset.id)
                        let isCurrentlyActive = (dnsManager.currentMode == .fastBrowsing && isSelectedPreset)
                        
                        Button(action: {
                            dnsManager.applyFastPreset(preset)
                        }) {
                            HStack(spacing: 4) {
                                Text(preset.icon)
                                    .font(.system(size: 11))
                                Text(preset.name)
                                    .font(.system(size: 11.5, weight: isSelectedPreset ? .bold : .medium))
                            }
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity)
                            .frame(height: 25)
                            .background(
                                isCurrentlyActive 
                                    ? Color.purple.opacity(0.25)
                                    : (isSelectedPreset ? Color.purple.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                            )
                            .foregroundColor(isSelectedPreset ? .purple : .primary)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelectedPreset ? Color.purple.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("\(preset.name) (\(preset.formattedIPs)): \(preset.description)")
                        .disabled(dnsManager.isUpdating)
                    }
                }
                
                // 3. Stream Mode Button
                Button(action: {
                    dnsManager.switchMode(to: .stream)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(dnsManager.currentMode == .stream ? "In Stream Mode" : "Switch to Stream Mode (SmartDNS)")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        dnsManager.currentMode == .stream 
                            ? Color.green.opacity(0.55) 
                            : Color.green
                    )
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .disabled(dnsManager.isUpdating || dnsManager.currentMode == .stream)
                
                // 4. Normal Mode Button
                Button(action: {
                    dnsManager.switchMode(to: .normal)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12, weight: .semibold))
                        Text(dnsManager.currentMode == .normal ? "In Normal Mode" : "Switch to Normal Mode (Automatic)")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        dnsManager.currentMode == .normal 
                            ? Color.blue.opacity(0.55) 
                            : Color.blue
                    )
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .disabled(dnsManager.isUpdating || dnsManager.currentMode == .normal)
            }
            
            // Mode-specific Context Notes
            if dnsManager.currentMode == .fastBrowsing {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(dnsManager.selectedFastPreset.icon)
                            .font(.caption)
                        Text("\(dnsManager.selectedFastPreset.name) DNS Active")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                    
                    Text(dnsManager.selectedFastPreset.description)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("• Primary: \(dnsManager.selectedFastPreset.primaryIP)  |  Secondary: \(dnsManager.selectedFastPreset.secondaryIP)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            } else if dnsManager.currentMode == .stream {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Safari Streaming Note:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    Text("• Ensure iCloud Private Relay is turned OFF / Paused in System Settings for Safari.")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("• Reactivate your IP on SmartDNSProxy if your network IP changes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button("Open SmartDNSProxy Account") {
                        dnsManager.openSmartDNSAccount()
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            }
            
            // Status Message Footer
            if let msg = dnsManager.lastMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(msg.contains("Error") ? .red : .secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Utility Links
            HStack {
                Button(action: {
                    dnsManager.flushDNSCache()
                }) {
                    Label("Flush Cache", systemImage: "sparkles")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 360)
    }
    
    @ViewBuilder
    private var modeBadgeView: some View {
        let (text, color): (String, Color) = {
            switch dnsManager.currentMode {
            case .stream:
                return ("⚡ STREAMING", .green)
            case .fastBrowsing:
                return ("🚀 FAST BROWSING", .purple)
            case .normal:
                return ("🌐 AUTOMATIC", .blue)
            case .custom:
                return ("⚙️ MANUAL DNS", .orange)
            case .unknown:
                return ("❓ UNKNOWN", .secondary)
            }
        }()
        
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
    
    private func relayColor(_ status: PrivateRelayStatus) -> Color {
        switch status {
        case .active:
            return .green
        case .paused:
            return .orange
        case .off:
            return .red
        case .unknown:
            return .gray
        }
    }
}
