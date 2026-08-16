import SwiftUI

@main
struct DNS_SwitcherApp: App {
    @StateObject private var dnsManager = DNSManager()
    
    var body: some Scene {
        MenuBarExtra {
            ContentView(dnsManager: dnsManager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuBarIcon)
                Text(menuBarTitle)
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    private var menuBarIcon: String {
        switch dnsManager.currentMode {
        case .stream:
            return "play.tv.fill"
        case .fastBrowsing:
            return "bolt.fill"
        case .normal:
            return "globe"
        case .custom:
            return "gearshape"
        case .unknown:
            return "network"
        }
    }
    
    private var menuBarTitle: String {
        switch dnsManager.currentMode {
        case .stream:
            return "SmartDNS"
        case .fastBrowsing:
            return "Fast DNS"
        case .normal:
            return "DNS"
        case .custom:
            return "Manual"
        case .unknown:
            return "DNS"
        }
    }
}
