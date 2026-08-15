import SwiftUI

struct SettingsView: View {
    @ObservedObject var dnsManager: DNSManager
    var onBack: () -> Void
    
    @State private var selectedPrimary: SmartDNSServer
    @State private var selectedSecondary: SmartDNSServer
    @State private var showAppliedAlert: Bool = false
    
    init(dnsManager: DNSManager, onBack: @escaping () -> Void) {
        self.dnsManager = dnsManager
        self.onBack = onBack
        _selectedPrimary = State(initialValue: dnsManager.primaryServer)
        _selectedSecondary = State(initialValue: dnsManager.secondaryServer)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Back")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("DNS Server Settings")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Balance alignment
                Color.clear
                    .frame(width: 44, height: 1)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Quick European & Popular Presets
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                            Text("Quick Presets (UK & Europe)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 6) {
                            ForEach(SmartDNSCatalog.presets) { preset in
                                let isSelected = (selectedPrimary == preset.primary && selectedSecondary == preset.secondary)
                                Button(action: {
                                    selectedPrimary = preset.primary
                                    selectedSecondary = preset.secondary
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(preset.name)
                                                .font(.caption)
                                                .fontWeight(isSelected ? .bold : .medium)
                                                .foregroundColor(isSelected ? .blue : .primary)
                                            
                                            Text("\(preset.primary.ip)  •  \(preset.secondary.ip)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color.blue.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Custom Selection Pickers
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom 2-Server Selection")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        // Primary Server Picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Primary DNS Server:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $selectedPrimary) {
                                ForEach(ServerRegion.allCases, id: \.self) { region in
                                    Section(header: Text(region.rawValue)) {
                                        ForEach(SmartDNSCatalog.allServers.filter { $0.region == region }) { server in
                                            Text("\(server.flag) \(server.city) (\(server.ip))")
                                                .tag(server)
                                        }
                                    }
                                }
                            }
                            .labelsHidden()
                        }
                        
                        // Secondary Server Picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("2. Secondary DNS Server (Fallback):")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $selectedSecondary) {
                                ForEach(ServerRegion.allCases, id: \.self) { region in
                                    Section(header: Text(region.rawValue)) {
                                        ForEach(SmartDNSCatalog.allServers.filter { $0.region == region }) { server in
                                            Text("\(server.flag) \(server.city) (\(server.ip))")
                                                .tag(server)
                                        }
                                    }
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .frame(maxHeight: 280)
            
            Divider()
            
            // Selected Summary & Apply Buttons
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected Target:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(selectedPrimary.flag) \(selectedPrimary.city) + \(selectedSecondary.flag) \(selectedSecondary.city)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if showAppliedAlert {
                        Text("Saved!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                            .transition(.opacity)
                    }
                }
                
                HStack(spacing: 8) {
                    Button(action: {
                        dnsManager.updateServers(primary: selectedPrimary, secondary: selectedSecondary, applyImmediately: false)
                        withAnimation {
                            showAppliedAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showAppliedAlert = false
                            }
                            onBack()
                        }
                    }) {
                        Text("Save Preset")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        dnsManager.updateServers(primary: selectedPrimary, secondary: selectedSecondary, applyImmediately: true)
                        withAnimation {
                            showAppliedAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            onBack()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                            Text("Apply to Wi-Fi")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.green)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 350)
    }
}
