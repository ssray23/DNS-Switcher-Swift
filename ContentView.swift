import SwiftUI

struct ContentView: View {
    @ObservedObject var dnsManager: DNSManager
    
    var body: some View {
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
                    
                    Text(dnsManager.currentMode == .stream ? "⚡ STREAMING" : "🌐 AUTOMATIC")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(dnsManager.currentMode == .stream ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .foregroundColor(dnsManager.currentMode == .stream ? .green : .blue)
                        .cornerRadius(6)
                }
                
                // DNS IPs
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current DNS Servers:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if dnsManager.currentDNS.isEmpty || dnsManager.currentDNS == ["There aren't any DNS Servers set on Wi-Fi."] {
                        Text("Automatic (DHCP / Router)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(dnsManager.currentDNS, id: \.self) { ip in
                            HStack {
                                Text(ip)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                if DNSManager.smartDNSIPs.contains(ip) {
                                    Text("SmartDNS")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
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
            
            // Mode Control Buttons
            VStack(spacing: 8) {
                // Stream Mode Button
                Button(action: {
                    dnsManager.switchMode(to: .stream)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.tv.fill")
                        Text(dnsManager.currentMode == .stream ? "In Stream Mode" : "Switch to Stream Mode (SmartDNS)")
                            .fontWeight(.semibold)
                    }
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        dnsManager.currentMode == .stream 
                            ? Color.green.opacity(0.55) 
                            : Color.green
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(dnsManager.isUpdating || dnsManager.currentMode == .stream)
                
                // Normal Mode Button
                Button(action: {
                    dnsManager.switchMode(to: .normal)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                        Text(dnsManager.currentMode == .normal ? "In Normal Mode" : "Switch to Normal Mode (Automatic)")
                            .fontWeight(.semibold)
                    }
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        dnsManager.currentMode == .normal 
                            ? Color.blue.opacity(0.5) 
                            : Color.blue
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(dnsManager.isUpdating || dnsManager.currentMode == .normal)
            }
            
            if dnsManager.currentMode == .stream {
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
        .frame(width: 340)
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
