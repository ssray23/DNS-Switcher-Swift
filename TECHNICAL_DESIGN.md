# Technical Design Document - DNS Switcher (macOS Swift Application)

## 1. Executive Overview

**DNS Switcher** is a native macOS menu bar status application built in Swift and SwiftUI. It enables effortless one-click switching between:
1. **Fast Browsing Mode** (High-speed & secure public DNS: Cloudflare, Google, Quad9)
2. **Stream Mode** (Configured with SmartDNSProxy IP addresses for streaming unblocking)
3. **Normal Mode** (Automatic DHCP network routing)

In addition, it detects the real-time status of macOS **iCloud Private Relay**, flushes system mDNS/DNS caches, and provides direct shortcuts to relevant macOS System Settings panels.

---

## 2. Architectural Overview

The application follows an Event-Driven MVVM Architecture using SwiftUI and Combine (`ObservableObject`).

```
┌───────────────────────────────────────────────────────────┐
│                    macOS Menu Bar                         │
│             (SwiftUI MenuBarExtra Extra Scene)            │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│                     ContentView                           │
│     • Mode Toggle Controls   • Private Relay Badge        │
│     • Fast DNS Quick Pills   • Active DNS IP Badges       │
│     • Status Context Notes   • Responsive Multiline Text  │
└─────────────────────────────┬─────────────────────────────┘
                              │ @ObservedObject / @Published
                              ▼
┌───────────────────────────────────────────────────────────┐
│                     DNSManager                            │
│     • Interface Detection    • Fast Preset Manager        │
│     • Private Relay Parser   • Privileged Shell Exec      │
│     • State Classification   • Cache Flush Dispatch       │
└─────────────────────────────┬─────────────────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          ▼                                       ▼
┌──────────────────┐                    ┌───────────────────┐
│ networksetup CLI │                    │  AppleScript      │
│ dscacheutil      │                    │  NSAppleScript    │
│ mDNSResponder    │                    │ (Admin Elevation) │
└──────────────────┘                    └───────────────────┘
```

---

## 3. Core Components

### 3.1 `DNS_SwitcherApp.swift` (App Entry Point)
- **Role**: Main application initialization point.
- **Implementation**: Uses SwiftUI `MenuBarExtra` scene with `.window` style.
- **Dynamic Label**: Displays dynamic icon (`bolt.fill` for Fast Browsing, `play.tv.fill` for SmartDNS, `globe` for Normal Mode, `gearshape` for Manual DNS) and title (`Fast DNS`, `SmartDNS`, `DNS`).
- **Agent Mode**: Configured with `LSUIElement = true` in `Info.plist`, hiding the application from the Dock and command-tab switcher to operate seamlessly as a lightweight menu bar utility.

### 3.2 `SmartDNSServer.swift` (Server Catalog & Presets)
- **Role**: Data model cataloging worldwide SmartDNSProxy servers, paired configurations, and Fast DNS providers.
- **Features**:
  - `FastDNSPreset` and `FastDNSCatalog`:
    - **Cloudflare** (`1.1.1.1` / `1.0.0.1`): Consistently ranks #1 in global speed tests with a strong focus on user privacy.
    - **Google** (`8.8.8.8` / `8.8.4.4`): Highly stable and fast, though it logs query data for analytics.
    - **Quad9** (`9.9.9.9` / `149.112.112.112`): Balances fast response times with automated malware blocking.
  - `SmartDNSServer` and `SmartDNSCatalog`: Full catalog covering UK & Europe (London, Frankfurt, Paris, Amsterdam, Dublin, Copenhagen, Madrid, Milan, Zurich, Stockholm, Istanbul), North America, Asia-Pacific, Middle East, and Latin America.
  - `ServerPairPreset`: Instant 2-server switching pairs (e.g. `London + Frankfurt`, `London + Paris`, `Amsterdam + Seoul`, `US East + Copenhagen`).

### 3.3 `DNSManager.swift` (Service & Business Logic Model)
- **Role**: `ObservableObject` handling network status queries, fast preset management, server pair management, system command executions, and state management.
- **Published Properties**:
  - `selectedFastPreset`: Selected Fast Browsing provider model (`Cloudflare`, `Google`, or `Quad9`), persisted in `UserDefaults`.
  - `primaryServer` & `secondaryServer`: Selected primary and secondary SmartDNS server instances, persisted in `UserDefaults`.
  - `activeSmartDNSIPs`: Dynamic array of IPs configured from selected server models.
  - `wifiInterface`: Auto-detected active Wi-Fi interface (e.g., `Wi-Fi`).
  - `currentDNS`: Active DNS IP server addresses.
  - `currentMode`: Active mode (`.fastBrowsing`, `.stream`, `.normal`, `.custom`, or `.unknown`).
  - `relayStatus`: Parsed Private Relay state (`.active`, `.paused`, `.off`).
  - `isUpdating`: Async lock flag preventing duplicate executions.
  - `lastMessage`: Status and error feedback messages.

#### Key Workflows:
1. **Network Interface Discovery**:
   Runs `/usr/sbin/networksetup -listallnetworkservices` to find the active Wi-Fi/Airport service.
2. **DNS Retrieval & State Classification**:
   Runs `/usr/sbin/networksetup -getdnsservers <interface>` to extract current DNS server configurations.
   - If current servers match a Fast Browsing preset (Cloudflare, Google, Quad9), mode is classified as `.fastBrowsing`.
   - If current servers match active `activeSmartDNSIPs` or known SmartDNS catalog servers, mode is `.stream`.
   - If empty (or DHCP unset), mode is `.normal` (`Automatic (DHCP / Router)`).
   - If other manual DNS IPs are present, mode is `.custom` (`MANUAL DNS`).
3. **iCloud Private Relay Parsing**:
   Reads macOS `com.apple.networkserviceproxy` defaults export. Evaluates the nested `NSPServiceStatusManagerInfo` binary property list to check `PrivacyProxyServiceStatus`:
   - `1` = Active (or Paused if specific network status != 1)
   - `2` = Paused
   - `Other` = Off
4. **Automatic Real-time Status Refreshing**:
   - **Background Polling**: Runs a lightweight background timer (2.5s interval) while the application menu popover is open.
   - **App Activation Observer**: Listens for `NSApplication.didBecomeActiveNotification` to immediately trigger a state refresh when returning to DNS Switcher.
5. **Privileged Command Execution**:
   Updates network DNS configuration and clears DNS caches using `NSAppleScript` with administrator authorization (`do shell script ... with administrator privileges`).

### 3.4 `SettingsView.swift` (Segmented Settings Panel)
- **Role**: Dedicated SwiftUI settings panel with segmented navigation:
  - **⚡ Fast Browsing Tab**: Rich provider cards for Cloudflare, Google, and Quad9 with speed/privacy/security details and 1-click apply.
  - **📺 SmartDNS Tab**: Curated UK & European 2-server paired presets and custom Primary/Secondary dropdown pickers.

### 3.5 `ContentView.swift` (Main Dashboard View)
- **Role**: Modern SwiftUI View rendered inside the menu bar popover.
- **Features**:
  - **Status Card**: Visual badges (`modeBadgeView`) displaying current active interface, active DNS IPs with provider badges (`⚡ Cloudflare`, `🌐 Google`, `🛡️ Quad9`) and SmartDNS city/flag badges, mode status (`🚀 FAST BROWSING`, `⚡ STREAMING`, `🌐 AUTOMATIC`, or `⚙️ MANUAL DNS`), and color-coded Private Relay state badge.
  - **Active Target Indicator**: Displays selected target (Fast DNS provider or SmartDNS pair) with quick access to settings.
  - **Dynamic Mode Action Buttons**:
    - **Fast Browsing Button**: Vibrant purple styling (`Color.purple`) with quick switch pills for 1-click toggling between Cloudflare, Google, and Quad9.
    - **Stream Mode Button**: Displays active bright green (`Color.green`) for SmartDNS.
    - **Normal Mode Button**: Displays active bright macOS blue (`Color.blue`) for Automatic DHCP.
  - **Context Notes**: Shows provider features in Fast Browsing mode, or Safari Private Relay guidance in Stream mode.
  - **Quick Utility Toolbar**: One-click DNS cache flush (`dscacheutil -flushcache && killall -HUP mDNSResponder`), direct preferences link, and SmartDNSProxy web portal launcher.

---

## 4. Build & Distribution System (`build_app.sh`)

The standalone application bundle is built using a custom shell build pipeline:
1. **Swift Compilation**: Uses `swiftc -O -parse-as-library -target arm64-apple-macosx13.0` to compile all source files into a standalone arm64 Mach-O binary.
2. **Icon Asset Generation**: Converts `AppIcon.png` into standard `.iconset` resolutions (`16x16` up to `1024x1024@2x`) using `sips -s format png`, then compiles `AppIcon.icns` via `iconutil`.
3. **App Bundle Assembly**: Creates the standard macOS `.app` bundle structure:
   - `DNS Switcher.app/Contents/MacOS/DNS Switcher`
   - `DNS Switcher.app/Contents/Resources/AppIcon.icns`
   - `DNS Switcher.app/Contents/Info.plist`
4. **Target Location**: Installs the final application bundle to `/Users/suddharay/Applications/DNS Switcher.app`.

---

## 5. Security & Permission Considerations

- **Privilege Separation**: The application runs under standard unprivileged user permissions. Elevated permissions are requested strictly on-demand via macOS system authorization dialogs when changing network parameters.
- **Input Sanitization**: Command strings are properly escaped to prevent shell injection.
