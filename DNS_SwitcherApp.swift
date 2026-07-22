import SwiftUI

@main
struct DNS_SwitcherApp: App {
    @StateObject private var dnsManager = DNSManager()
    
    var body: some Scene {
        MenuBarExtra {
            ContentView(dnsManager: dnsManager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: dnsManager.currentMode == .stream ? "play.tv.fill" : "network")
                Text(dnsManager.currentMode == .stream ? "SmartDNS" : "DNS")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
