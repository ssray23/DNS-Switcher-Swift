# How DNS Works — A Beginner's Guide 🌐

If you have ever used the internet, you have used **DNS** thousands of times without even realizing it. 

This guide explains what DNS is, how it works behind the scenes, and why choosing the right DNS server makes your internet faster, safer, and more private.

---

## 1. The Simplest Analogy: The Internet's Contacts App 📱

Imagine wanting to call your friend **Alex**.
- You don't memorize Alex's 10-digit phone number (`+1-555-0199`).
- Instead, you open your phone's **Contacts App**, tap **"Alex"**, and your phone dials the number for you.

**DNS (Domain Name System)** is the exact same thing, but for the entire internet:

| What Humans Remember | What Computers Actually Need |
| :--- | :--- |
| `google.com` | `142.250.190.46` |
| `netflix.com` | `54.154.246.12` |
| `cloudflare.com` | `104.16.132.229` |

Computers and servers across the globe do not understand names like `google.com`—they only communicate using numerical addresses called **IP (Internet Protocol) Addresses**.

**DNS is the global phonebook that translates human-friendly website names into computer-friendly IP numbers.**

---

## 2. What Happens When You Visit a Website? ⏱️

Every single time you click a link or type a website name into your browser, a lightning-fast 4-step conversation happens in just a few milliseconds:

```
┌──────────────┐         1. "What is the IP for netflix.com?"         ┌──────────────┐
│              │ ───────────────────────────────────────────────────> │              │
│ Your Mac /   │                                                      │  DNS Server  │
│ Phone / PC   │ <─────────────────────────────────────────────────── │ (The Address │
│              │         2. "The IP address is 54.154.246.12"         │     Book)    │
└──────────────┘                                                      └──────────────┘
       │
       │ 3. Connects directly to 54.154.246.12
       ▼
┌──────────────┐
│  Netflix Web │
│    Server    │ ──── 4. Sends video & webpage back to your screen ───> You're watching!
└──────────────┘
```

### Step-by-Step Breakdown:
1. **You ask**: You type `netflix.com` in Safari, Chrome, or your favorite browser.
2. **Your computer asks DNS**: Your Mac instantly contacts your configured **DNS Server** and asks: *"Where is netflix.com located?"*
3. **DNS answers**: The DNS server looks up its global directory and answers: *"netflix.com lives at `54.154.246.12`."*
4. **Connection made**: Your browser connects directly to `54.154.246.12` and loads the website on your screen.

---

## 3. Why Does Choosing Your DNS Server Matter? 🎯

By default, your home Wi-Fi router assigns you whatever DNS server your Internet Service Provider (ISP) uses. However, your ISP's default DNS is often **slow**, **unfiltered**, and may **track your browsing history** for advertising analytics.

Switching to a modern, specialized DNS provider gives you distinct benefits:

```
                 ┌───────────────────────────────────────────────────────────┐
                 │                   Which DNS Fits You?                     │
                 └─────────────────────────────┬─────────────────────────────┘
                                               │
               ┌───────────────────────────────┼───────────────────────────────┐
               ▼                               ▼                               ▼
       🚀 Fast Browsing               📺 Streaming / Travel             🌐 Default / Auto
    (Cloudflare / Google / Quad9)            (SmartDNS)                 (Router / DHCP)
   • Ultra-fast page lookups         • Unblock foreign streams        • Standard connection
   • Malware & phishing filters      • No VPN speed loss              • ISP default routing
   • Enhanced privacy                • Direct video CDN speed
```

---

## 4. Understanding the Modes in DNS Switcher

### 🚀 1. Fast Browsing Mode (High-Speed & Security)
Fast public DNS providers run massive server networks around the world so your DNS queries resolve closer to you:

* **⚡ Cloudflare (`1.1.1.1` / `1.0.0.1`)**:
  * **Best For**: Maximum speed and privacy.
  * **Why**: Ranks #1 globally in response time. Cloudflare promises never to sell your data or log your personal IP address to disk.
* **🌐 Google Public DNS (`8.8.8.8` / `8.8.4.4`)**:
  * **Best For**: Rock-solid stability and global reliability.
  * **Why**: Backed by Google's global infrastructure, ensuring high uptime and fast lookups anywhere in the world.
* **🛡️ Quad9 (`9.9.9.9` / `149.112.112.112`)**:
  * **Best For**: Automated security and malware protection.
  * **Why**: Quad9 blocks malicious links, ransomware, and phishing domains before your browser even connects to them.

---

### 📺 2. Stream Mode (SmartDNS)
When you travel or want to access streaming content from another region (such as Sony LIV, Hotstar, BBC iPlayer, etc.):
* **How Regular VPNs Work**: A traditional VPN sends *100% of your internet traffic* (including huge video files) through an encrypted server far away, which can slow down your stream or trigger VPN blocks.
* **How SmartDNS Works**: SmartDNS only reroutes the tiny **location-checking DNS lookup**. Once the streaming service confirms you're allowed to watch, the actual video streams directly from the fastest local server at full internet speed!

> [!NOTE]
> **Why turn off iCloud Private Relay during Stream Mode?**
> Apple's iCloud Private Relay acts as a built-in proxy in Safari. If active, it overrides custom DNS settings in Safari and routes queries through Apple's servers instead. Turning it off or pausing it allows SmartDNS to do its job.

---

### 🌐 3. Normal Mode (Automatic DHCP)
* **What it does**: Clears any custom DNS servers from your Wi-Fi settings.
* **How it works**: Your Mac automatically asks your local Wi-Fi router for its default DNS settings via standard DHCP.
* **Best For**: Everyday standard browsing when you want zero customizations.

---

## 5. Quick Comparison Table

| DNS Provider / Mode | Primary IP | Secondary IP | Main Strength |
| :--- | :--- | :--- | :--- |
| ⚡ **Cloudflare** | `1.1.1.1` | `1.0.0.1` | ⚡ Fastest speed + strict zero-logging privacy |
| 🌐 **Google** | `8.8.8.8` | `8.8.4.4` | 🌍 High uptime & global stability |
| 🛡️ **Quad9** | `9.9.9.9` | `149.112.112.112` | 🔒 Automated threat & malware blocking |
| 📺 **SmartDNS** | *Custom City IP* | *Fallback City IP* | 🎬 Unblocks international streaming libraries |
| 🌐 **Automatic** | *Router Assigned* | *Router Assigned* | ⚙️ Default standard home network settings |

---

## 6. Frequently Asked Questions (FAQ)

### Does changing my DNS change my computer's IP address?
**No.** DNS only changes the "address book" your computer uses to look up website names. Your computer's public IP address assigned by your internet provider remains the same.

### Will changing DNS slow down my download speeds or game latency?
**No.** DNS only affects the initial fraction of a second when your computer looks up where a website is located. Once connected, your download and upload speeds depend entirely on your internet connection. In fact, a faster DNS makes websites start loading noticeably quicker!

### What is DNS Caching and why do we "Flush Cache"?
Your computer remembers (caches) recently looked-up website addresses so it doesn't have to ask the DNS server every single second. When you switch DNS modes, flushing the cache forces your computer to forget old lookups and use the new DNS server immediately.

---

*Authored for **DNS Switcher (Swift)** — Made to make DNS simple and accessible for everyone.*
