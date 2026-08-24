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
│     • Status Context Notes   • Latency Badges (ms)        │
└─────────────────────────────┬─────────────────────────────┘
                              │ @ObservedObject / @Published
                              ▼
┌───────────────────────────────────────────────────────────┐
│                     DNSManager                            │
│     • Interface Detection    • Fast Preset Manager        │
│     • Private Relay Parser   • Privileged Shell Exec      │
│     • State Classification   • Cache Flush Dispatch       │
│     • Latency Benchmarking   • Auto-Select Fastest        │
└────────────┬────────────────────────────┬─────────────────┘
             │                            │
  ┌──────────┴──────────┐     ┌───────────┴──────────────┐
  ▼                     ▼     ▼                          ▼
┌──────────────────┐  ┌───────────────────┐  ┌───────────────────────┐
│ networksetup CLI │  │  AppleScript      │  │ DNSBenchmarkEngine    │
│ dscacheutil      │  │  NSAppleScript    │  │ • UDP Port 53 Probes  │
│ mDNSResponder    │  │ (Admin Elevation) │  │ • Concurrent TaskGroup│
└──────────────────┘  └───────────────────┘  │ • ms Latency Timing   │
                                             └───────────────────────┘
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
  - `serverLatencies`: Dictionary mapping server IP addresses to measured round-trip latency in milliseconds (`[String: Int]`).
  - `isBenchmarking`: Boolean flag indicating whether a benchmark run is in progress (drives UI loading indicators).

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
6. **Latency Benchmarking & Auto-Selection**:
   - `runBenchmark()`: Collects all unique server IPs (Fast DNS presets + SmartDNS catalog), dispatches concurrent probes via `DNSBenchmarkEngine`, and publishes results to `serverLatencies`.
   - `autoSelectFastestFastDNS()`: Selects the Fast DNS preset with the lowest measured primary IP latency.
   - `autoSelectFastestSmartDNSPair()`: Ranks all SmartDNS servers by latency and assigns the top two as Primary and Secondary.

### 3.4 `SettingsView.swift` (Segmented Settings Panel)
- **Role**: Dedicated SwiftUI settings panel with segmented navigation:
  - **⚡ Fast Browsing Tab**: Rich provider cards for Cloudflare, Google, and Quad9 with speed/privacy/security details and 1-click apply.
  - **📺 SmartDNS Tab**: Curated UK & European 2-server paired presets and custom Primary/Secondary dropdown pickers.
- **Benchmark Toolbar**:
  - **"Test Speeds" Button**: Triggers a full concurrent benchmark run across all servers. Displays a spinning progress indicator during execution.
  - **"Auto-Select Fastest" Button**: Analyses benchmark results and automatically selects the lowest-latency server(s) for the active tab.
- **Latency Badges (`LatencyBadge` View)**: Reusable color-coded badge component displayed alongside every server card, preset row, and dropdown option:
  - 🟢 `< 35 ms` (Green): Ultra-fast — ideal for instant 4K ramp-up and zero bufferbloat.
  - 🟡 `35–80 ms` (Orange): Standard performance.
  - 🔴 `> 80 ms` (Red): High latency — cross-continental routing.
  - ⚪ `-- ms` (Grey): Not yet tested.
- **Auto-Benchmark on Appear**: Automatically runs a benchmark when the Settings panel opens and no prior results exist.

### 3.5 `ContentView.swift` (Main Dashboard View)
- **Role**: Modern SwiftUI View rendered inside the menu bar popover.
- **Features**:
  - **Status Card**: Visual badges (`modeBadgeView`) displaying current active interface, active DNS IPs with provider badges (`⚡ Cloudflare`, `🌐 Google`, `🛡️ Quad9`) and SmartDNS city/flag badges, mode status (`🚀 FAST BROWSING`, `⚡ STREAMING`, `🌐 AUTOMATIC`, or `⚙️ MANUAL DNS`), and color-coded Private Relay state badge.
  - **Active Target Indicator**: Displays selected target (Fast DNS provider or SmartDNS pair) with quick access to settings.
  - **Latency Tags**: Displays measured latency (ms) with color-coded `LatencyBadge` next to each active DNS server IP in the status card.
  - **Dynamic Mode Action Buttons**:
    - **Fast Browsing Button**: Vibrant purple styling (`Color.purple`) with quick switch pills for 1-click toggling between Cloudflare, Google, and Quad9.
    - **Stream Mode Button**: Displays active bright green (`Color.green`) for SmartDNS.
    - **Normal Mode Button**: Displays active bright macOS blue (`Color.blue`) for Automatic DHCP.
  - **Context Notes**: Shows provider features in Fast Browsing mode, or Safari Private Relay guidance in Stream mode.
  - **Quick Utility Toolbar**: One-click DNS cache flush (`dscacheutil -flushcache && killall -HUP mDNSResponder`), direct preferences link, and SmartDNSProxy web portal launcher.

### 3.6 `DNSBenchmarkEngine.swift` (Latency Probe Engine)
- **Role**: Singleton (`DNSBenchmarkEngine.shared`) that measures real DNS query round-trip latency to any server IP using raw UDP socket probes.
- **Implementation Details**:
  - **DNS Query Construction**: Builds a minimal RFC 1035-compliant DNS query packet (12-byte header + A-record question for `apple.com`) with a fixed transaction ID (`0x1A2B`) for response verification.
  - **Socket Layer**: Uses POSIX BSD sockets (`socket()`, `sendto()`, `recvfrom()`) with `SOCK_DGRAM` / `IPPROTO_UDP` to send queries to port 53. Configures `SO_RCVTIMEO` and `SO_SNDTIMEO` for a 1.5-second timeout.
  - **Precision Timing**: Measures elapsed nanoseconds between `sendto()` and `recvfrom()` using `DispatchTime.now().uptimeNanoseconds`, converting to integer milliseconds.
  - **Response Validation**: Verifies that the received packet contains at least 12 bytes (minimum DNS header) and that the transaction ID matches the original query, preventing false positives from stale or spoofed responses.
  - **Concurrency**:
    - `probeLatency(serverIP:)`: Wraps the synchronous BSD socket call in `withCheckedContinuation` dispatched to `DispatchQueue.global(qos: .userInitiated)` for non-blocking async usage.
    - `probeAll(ips:)`: Uses Swift structured concurrency `withTaskGroup` to probe all server IPs in parallel, returning a `[String: Int]` dictionary of IP → latency (ms).
  - **Sendable Safety**: Conforms to `Sendable` protocol for safe concurrent access across task groups.

---

## 4. Build & Distribution System (`build_app.sh`)

The standalone application bundle is built using a custom shell build pipeline:
1. **Swift Compilation**: Uses `swiftc -O -parse-as-library -target arm64-apple-macosx13.0` to compile all source files (`DNS_SwitcherApp.swift`, `ContentView.swift`, `SettingsView.swift`, `SmartDNSServer.swift`, `DNSManager.swift`, `DNSBenchmarkEngine.swift`) into a standalone arm64 Mach-O binary.
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
