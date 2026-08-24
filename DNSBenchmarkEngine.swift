import Foundation

public final class DNSBenchmarkEngine: Sendable {
    public static let shared = DNSBenchmarkEngine()
    
    private init() {}
    
    /// Standard DNS Query Packet for "apple.com" (Type A, Class IN)
    private static let standardDNSQuery: [UInt8] = [
        0x1A, 0x2B, // Transaction ID
        0x01, 0x00, // Standard query with recursion desired
        0x00, 0x01, // Questions: 1
        0x00, 0x00, // Answer RRs: 0
        0x00, 0x00, // Authority RRs: 0
        0x00, 0x00, // Additional RRs: 0
        // "apple.com"
        0x05, 0x61, 0x70, 0x70, 0x6C, 0x65, // length 5, "apple"
        0x03, 0x63, 0x6F, 0x6D,             // length 3, "com"
        0x00,                               // null terminator
        0x00, 0x01,                         // Type: A (Host Address)
        0x00, 0x01                          // Class: IN (Internet)
    ]
    
    /// Probes a single DNS server IP via UDP port 53 and returns round-trip latency in milliseconds.
    /// Returns nil if unreachable, timed out, or socket error.
    public func probeLatency(serverIP: String, timeoutSeconds: Double = 1.5) async -> Int? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.syncProbe(serverIP: serverIP, timeoutSeconds: timeoutSeconds)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Probes multiple server IPs concurrently and returns a dictionary of [IP: Latency_in_ms].
    public func probeAll(ips: [String], timeoutSeconds: Double = 1.5) async -> [String: Int] {
        await withTaskGroup(of: (String, Int?).self) { group in
            for ip in ips {
                group.addTask {
                    let latency = await self.probeLatency(serverIP: ip, timeoutSeconds: timeoutSeconds)
                    return (ip, latency)
                }
            }
            
            var results: [String: Int] = [:]
            for await (ip, latency) in group {
                if let latency = latency {
                    results[ip] = latency
                }
            }
            return results
        }
    }
    
    private func syncProbe(serverIP: String, timeoutSeconds: Double) -> Int? {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_UDP
        
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(serverIP, "53", &hints, &res)
        guard status == 0, let serverAddr = res else {
            return nil
        }
        defer { freeaddrinfo(res) }
        
        let sock = socket(serverAddr.pointee.ai_family, serverAddr.pointee.ai_socktype, serverAddr.pointee.ai_protocol)
        guard sock >= 0 else {
            return nil
        }
        defer { close(sock) }
        
        // Configure socket timeout
        let sec = Int(timeoutSeconds)
        let usec = Int32((timeoutSeconds - Double(sec)) * 1_000_000)
        var tv = timeval(tv_sec: sec, tv_usec: usec)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        let queryData = DNSBenchmarkEngine.standardDNSQuery
        
        let startTime = DispatchTime.now()
        
        let sent = queryData.withUnsafeBytes { buffer in
            sendto(sock, buffer.baseAddress, buffer.count, 0, serverAddr.pointee.ai_addr, serverAddr.pointee.ai_addrlen)
        }
        
        guard sent == queryData.count else {
            return nil
        }
        
        var responseBuffer = [UInt8](repeating: 0, count: 512)
        var fromAddr = sockaddr_storage()
        var fromAddrLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        
        let bytesReceived = withUnsafeMutablePointer(to: &fromAddr) { ptr -> Int in
            let sockaddrPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self)
            return recvfrom(sock, &responseBuffer, responseBuffer.count, 0, sockaddrPtr, &fromAddrLen)
        }
        
        let endTime = DispatchTime.now()
        
        guard bytesReceived >= 12 else {
            return nil
        }
        
        // Verify transaction ID matches
        let transactionID = UInt16(responseBuffer[0]) << 8 | UInt16(responseBuffer[1])
        guard transactionID == 0x1A2B else {
            return nil
        }
        
        let elapsedNanos = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let latencyMs = Double(elapsedNanos) / 1_000_000.0
        return max(1, Int(round(latencyMs)))
    }
}
