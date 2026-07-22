# Technical Design Document - DNS Switcher (macOS Swift Application)

## 1. Executive Overview

**DNS Switcher** is a native macOS menu bar status application built in Swift and SwiftUI. It enables effortless one-click switching between **Stream Mode** (configured with SmartDNSProxy IP addresses) and **Normal Mode** (automatic DHCP network routing). In addition, it detects the real-time status of macOS **iCloud Private Relay**, flushes system mDNS/DNS caches, and provides direct shortcuts to relevant macOS System Settings panels.

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
│     • Active DNS IP List     • Responsive Multiline Text  │
└─────────────────────────────┬─────────────────────────────┘
                              │ @ObservedObject / @Published
                              ▼
┌───────────────────────────────────────────────────────────┐
│                     DNSManager                            │
│     • Interface Detection    • Privileged Shell Exec      │
│     • Private Relay Parser   • Cache Flush Dispatch       │
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
- **Agent Mode**: Configured with `LSUIElement = true` in `Info.plist`, hiding the application from the Dock and command-tab switcher to operate seamlessly as a lightweight menu bar utility.

### 3.2 `DNSManager.swift` (Service & Business Logic Model)
- **Role**: `ObservableObject` handling network status queries, system command executions, and state management.
- **Published Properties**:
  - `wifiInterface`: Auto-detected active Wi-Fi interface (e.g., `Wi-Fi`).
  - `currentDNS`: Active DNS IP server addresses.
  - `currentMode`: Active mode (`.stream` vs `.normal`).
  - `relayStatus`: Parsed Private Relay state (`.active`, `.paused`, `.off`).
  - `isUpdating`: Async lock flag preventing duplicate executions.
  - `lastMessage`: Status and error feedback messages.

#### Key Workflows:
1. **Network Interface Discovery**:
   Runs `/usr/sbin/networksetup -listallnetworkservices` to find the active Wi-Fi/Airport service.
2. **DNS Retrieval**:
   Runs `/usr/sbin/networksetup -getdnsservers <interface>` to extract current DNS server configurations.
3. **iCloud Private Relay Parsing**:
   Reads macOS `com.apple.networkserviceproxy` defaults export. Evaluates the nested `NSPServiceStatusManagerInfo` binary property list to check `PrivacyProxyServiceStatus`:
   - `1` = Active (or Paused if specific network status != 1)
   - `2` = Paused
   - `Other` = Off
4. **Automatic Real-time Status Refreshing**:
   - **Background Polling**: Runs a lightweight background timer (2.5s interval) while the application menu popover is open.
   - **App Activation Observer**: Listens for `NSApplication.didBecomeActiveNotification` to immediately trigger a state refresh when the user returns to DNS Switcher after modifying Private Relay settings in macOS System Settings.
5. **Privileged Command Execution**:
   To update network DNS configuration and clear DNS caches without requiring the application to run as root, `DNSManager` constructs shell script pipelines executed via `NSAppleScript` with administrator authorization (`do shell script ... with administrator privileges`). Single-quoted interface arguments prevent AppleScript string escaping vulnerabilities.

### 3.3 `ContentView.swift` (UI & User Experience)
- **Role**: Modern SwiftUI View rendered inside the menu bar popover.
- **Features**:
  - **Status Card**: Visual badges displaying the current active interface, active DNS IPs, and color-coded Private Relay state badge.
  - **Dynamic Mode Action Buttons**:
    - **Stream Mode Button**: Displays active bright green (`Color.green`) with `"Switch to Stream Mode (SmartDNS)"` when in Normal Mode; displays dimmed green (`Color.green.opacity(0.55)`) with `"In Stream Mode"` when disabled in Stream Mode.
    - **Normal Mode Button**: Displays active bright macOS blue (`Color.blue`) with `"Switch to Normal Mode (Automatic)"` when in Stream Mode; displays dimmed blue (`Color.blue.opacity(0.5)`) with `"In Normal Mode"` when disabled in Normal Mode.
  - **Manage... Button**: Styled with a native macOS bordered button style (`.buttonStyle(.bordered)` with `.tint(.blue)`), giving it a clear interactive border and hover/pressed states.
  - **Multiline Note Box**: Uses `.lineLimit(nil)` and `.fixedSize(horizontal: false, vertical: true)` to ensure instructions and Safari streaming notes wrap dynamically without truncation.
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
