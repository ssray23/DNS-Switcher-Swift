import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case fastBrowsing = "Fast Browsing"
    case smartDNS = "SmartDNS"
    
    var id: String { rawValue }
}

struct SettingsView: View {
    @ObservedObject var dnsManager: DNSManager
    var onBack: () -> Void
    
    @State private var selectedTab: SettingsTab = .fastBrowsing
    @State private var selectedPrimary: SmartDNSServer
    @State private var selectedSecondary: SmartDNSServer
    @State private var selectedFast: FastDNSPreset
    @State private var showAppliedAlert: Bool = false
    
    init(dnsManager: DNSManager, onBack: @escaping () -> Void) {
        self.dnsManager = dnsManager
        self.onBack = onBack
        _selectedPrimary = State(initialValue: dnsManager.primaryServer)
        _selectedSecondary = State(initialValue: dnsManager.secondaryServer)
        _selectedFast = State(initialValue: dnsManager.selectedFastPreset)
        
        // Default tab to currently active mode if relevant
        if dnsManager.currentMode == .stream {
            _selectedTab = State(initialValue: .smartDNS)
        } else {
            _selectedTab = State(initialValue: .fastBrowsing)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            // Tab Selector
            Picker("Mode Tab", selection: $selectedTab) {
                Text("⚡ Fast Browsing").tag(SettingsTab.fastBrowsing)
                Text("📺 SmartDNS (Stream)").tag(SettingsTab.smartDNS)
            }
            .pickerStyle(.segmented)
            
            Divider()
            
            // Tab Content
            if selectedTab == .fastBrowsing {
                fastBrowsingTabContent
            } else {
                smartDNSTabContent
            }
        }
        .padding(16)
        .frame(width: 360, height: 500)
    }
    
    // MARK: - Fast Browsing Tab Content
    private var fastBrowsingTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("High-Speed & Secure Public DNS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    ForEach(FastDNSCatalog.allPresets) { preset in
                        let isSelected = (selectedFast.id == preset.id)
                        let isCurrentlyActive = (dnsManager.currentMode == .fastBrowsing && dnsManager.selectedFastPreset.id == preset.id)
                        
                        Button(action: {
                            selectedFast = preset
                            dnsManager.selectedFastPreset = preset
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Text(preset.icon)
                                            .font(.body)
                                        Text(preset.name)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(isSelected ? .purple : .primary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isCurrentlyActive {
                                        Text("ACTIVE")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.purple)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    } else if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                            .font(.caption)
                                    }
                                }
                                
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(nil)
                                
                                HStack(spacing: 8) {
                                    Label(preset.primaryIP, systemImage: "network")
                                        .font(.system(size: 10, design: .monospaced))
                                    Label(preset.secondaryIP, systemImage: "network")
                                        .font(.system(size: 10, design: .monospaced))
                                }
                                .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? Color.purple.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.purple.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 2)
            }
            .frame(height: 310)
            
            Divider()
            
            // Bottom Action for Fast DNS
            VStack(spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Selected Provider:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(selectedFast.icon) \(selectedFast.name) (\(selectedFast.formattedIPs))")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                
                Button(action: {
                    dnsManager.applyFastPreset(selectedFast)
                    withAnimation {
                        showAppliedAlert = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onBack()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                        Text("Apply \(selectedFast.name) to Wi-Fi")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color.purple)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - SmartDNS Tab Content
    private var smartDNSTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // Quick European & Popular Presets
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                            Text("Saved Presets (UK & Europe)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 6) {
                            ForEach(dnsManager.presets) { preset in
                                let isSelected = (selectedPrimary == preset.primary && selectedSecondary == preset.secondary)
                                HStack(spacing: 0) {
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
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if preset.isCustom {
                                        Button(action: {
                                            dnsManager.removePreset(byId: preset.id)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .padding(.trailing, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Remove Custom Preset")
                                    }
                                }
                                .background(isSelected ? Color.blue.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Custom Selection Pickers
                    VStack(alignment: .leading, spacing: 10) {
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
                .padding(.trailing, 2)
            }
            .frame(height: 310)
            
            Divider()
            
            // Bottom Action for SmartDNS
            VStack(spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Selected Target:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(selectedPrimary.flag) \(selectedPrimary.city) + \(selectedSecondary.flag) \(selectedSecondary.city)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if showAppliedAlert {
                        Text(dnsManager.isPresetSaved(primary: selectedPrimary, secondary: selectedSecondary) ? "Saved!" : "Unsaved!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                            .transition(.opacity)
                    }
                }
                
                HStack(spacing: 8) {
                    let isSaved = dnsManager.isPresetSaved(primary: selectedPrimary, secondary: selectedSecondary)
                    
                    Button(action: {
                        if isSaved {
                            dnsManager.unsavePreset(primary: selectedPrimary, secondary: selectedSecondary)
                        } else {
                            dnsManager.savePreset(primary: selectedPrimary, secondary: selectedSecondary)
                        }
                        withAnimation {
                            showAppliedAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation {
                                showAppliedAlert = false
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isSaved ? "bookmark.slash.fill" : "bookmark.fill")
                                .font(.caption2)
                            Text(isSaved ? "Unsave Preset" : "Save Preset")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(isSaved ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(isSaved ? Color.red : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSaved ? Color.clear : Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
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
                                .font(.caption2)
                            Text("Apply to Wi-Fi")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Color.green)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
