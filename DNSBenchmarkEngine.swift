import Foundation

public final class DNSBenchmarkEngine: Sendable {
    public static let shared = DNSBenchmarkEngine()
    
    private init() {}
    
    /// Standard DNS Query Packet for "apple.com" (Type A, Class IN) - Used for basic ping
    private static let standardDNSQuery: [UInt8] = {
        return buildDNSQuery(domain: "apple.com", transactionID: 0x1A2B)
    }()
    
    // MARK: - Basic DNS Ping (Fast Browsing)
    
    /// Probes a single DNS server IP via UDP port 53 and returns round-trip latency in milliseconds.
    public func probeLatency(serverIP: String, timeoutSeconds: Double = 1.5) async -> Int? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.syncProbe(serverIP: serverIP, timeoutSeconds: timeoutSeconds)
                continuation.resume(returning: result)
            }
        }
    }
    
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
        guard status == 0, let serverAddr = res else { return nil }
        defer { freeaddrinfo(res) }
        
        let sock = socket(serverAddr.pointee.ai_family, serverAddr.pointee.ai_socktype, serverAddr.pointee.ai_protocol)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
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
        guard sent == queryData.count else { return nil }
        
        var responseBuffer = [UInt8](repeating: 0, count: 512)
        var fromAddr = sockaddr_storage()
        var fromAddrLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        
        let bytesReceived = withUnsafeMutablePointer(to: &fromAddr) { ptr -> Int in
            let sockaddrPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self)
            return recvfrom(sock, &responseBuffer, responseBuffer.count, 0, sockaddrPtr, &fromAddrLen)
        }
        let endTime = DispatchTime.now()
        
        guard bytesReceived >= 12 else { return nil }
        let transactionID = UInt16(responseBuffer[0]) << 8 | UInt16(responseBuffer[1])
        guard transactionID == 0x1A2B else { return nil }
        
        let elapsedNanos = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let latencyMs = Double(elapsedNanos) / 1_000_000.0
        return max(1, Int(round(latencyMs)))
    }
    
    // MARK: - Advanced Streaming Route Benchmark (SmartDNS)
    
    public func probeAllStreamingRoutes(ips: [String], targetDomain: String, timeoutSeconds: Double = 2.0) async -> [String: Int] {
        await withTaskGroup(of: (String, Int?).self) { group in
            for ip in ips {
                group.addTask {
                    let latency = await self.benchmarkStreamingRoute(serverIP: ip, targetDomain: targetDomain, timeoutSeconds: timeoutSeconds)
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
    
    private func benchmarkStreamingRoute(serverIP: String, targetDomain: String, timeoutSeconds: Double) async -> Int? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.syncRouteBenchmark(serverIP: serverIP, targetDomain: targetDomain, timeoutSeconds: timeoutSeconds)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func syncRouteBenchmark(serverIP: String, targetDomain: String, timeoutSeconds: Double) -> Int? {
        let startTime = DispatchTime.now()
        
        // 1. DNS Resolution via specific server
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_UDP
        
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(serverIP, "53", &hints, &res)
        guard status == 0, let serverAddr = res else { return nil }
        defer { freeaddrinfo(res) }
        
        let sock = socket(serverAddr.pointee.ai_family, serverAddr.pointee.ai_socktype, serverAddr.pointee.ai_protocol)
        guard sock >= 0 else { return nil }
        
        let sec = Int(timeoutSeconds)
        let usec = Int32((timeoutSeconds - Double(sec)) * 1_000_000)
        var tv = timeval(tv_sec: sec, tv_usec: usec)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        let transactionID: UInt16 = UInt16.random(in: 1...65535)
        let queryData = DNSBenchmarkEngine.buildDNSQuery(domain: targetDomain, transactionID: transactionID)
        
        let sent = queryData.withUnsafeBytes { buffer in
            sendto(sock, buffer.baseAddress, buffer.count, 0, serverAddr.pointee.ai_addr, serverAddr.pointee.ai_addrlen)
        }
        guard sent == queryData.count else { close(sock); return nil }
        
        var responseBuffer = [UInt8](repeating: 0, count: 512)
        var fromAddr = sockaddr_storage()
        var fromAddrLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        
        let bytesReceived = withUnsafeMutablePointer(to: &fromAddr) { ptr -> Int in
            let sockaddrPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self)
            return recvfrom(sock, &responseBuffer, responseBuffer.count, 0, sockaddrPtr, &fromAddrLen)
        }
        close(sock)
        
        guard bytesReceived >= 12 else { return nil }
        
        let rxTxID = UInt16(responseBuffer[0]) << 8 | UInt16(responseBuffer[1])
        guard rxTxID == transactionID else { return nil }
        
        // 2. Extract Resolved IP
        guard let resolvedIP = DNSBenchmarkEngine.extractIPFromDNSResponse(buffer: responseBuffer, bytesRead: bytesReceived) else {
            return nil
        }
        
        // 3. Measure TCP Connect time to resolvedIP on port 443 (HTTPS)
        return DNSBenchmarkEngine.measureTCPConnectLatency(ip: resolvedIP, port: 443, timeoutSeconds: timeoutSeconds, startTime: startTime)
    }
    
    // MARK: - Helpers
    
    private static func buildDNSQuery(domain: String, transactionID: UInt16) -> [UInt8] {
        var packet: [UInt8] = []
        packet.append(contentsOf: [
            UInt8(truncatingIfNeeded: transactionID >> 8),
            UInt8(truncatingIfNeeded: transactionID & 0xFF),
            0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
        
        let parts = domain.split(separator: ".")
        for part in parts {
            let utf8Part = Array(part.utf8)
            packet.append(UInt8(utf8Part.count))
            packet.append(contentsOf: utf8Part)
        }
        packet.append(0x00) // end of QNAME
        packet.append(contentsOf: [0x00, 0x01, 0x00, 0x01]) // QTYPE A, QCLASS IN
        
        return packet
    }
    
    private static func extractIPFromDNSResponse(buffer: [UInt8], bytesRead: Int) -> String? {
        guard bytesRead >= 12 else { return nil }
        
        let qdcount = Int(buffer[4]) << 8 | Int(buffer[5])
        let ancount = Int(buffer[6]) << 8 | Int(buffer[7])
        guard ancount > 0 else { return nil }
        
        var offset = 12
        for _ in 0..<qdcount {
            skipName(buffer: buffer, offset: &offset)
            offset += 4
        }
        
        for _ in 0..<ancount {
            guard offset < bytesRead else { return nil }
            skipName(buffer: buffer, offset: &offset)
            guard offset + 10 <= bytesRead else { return nil }
            
            let type = Int(buffer[offset]) << 8 | Int(buffer[offset+1])
            let rdlength = Int(buffer[offset+8]) << 8 | Int(buffer[offset+9])
            offset += 10
            
            guard offset + rdlength <= bytesRead else { return nil }
            
            if type == 1 && rdlength == 4 {
                return "\(buffer[offset]).\(buffer[offset+1]).\(buffer[offset+2]).\(buffer[offset+3])"
            }
            offset += rdlength
        }
        return nil
    }
    
    private static func skipName(buffer: [UInt8], offset: inout Int) {
        while offset < buffer.count {
            let len = buffer[offset]
            if len == 0 {
                offset += 1
                break
            } else if (len & 0xC0) == 0xC0 {
                offset += 2
                break
            } else {
                offset += Int(len) + 1
            }
        }
    }
    
    private static func measureTCPConnectLatency(ip: String, port: Int, timeoutSeconds: Double, startTime: DispatchTime) -> Int? {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP
        
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(ip, String(port), &hints, &res)
        guard status == 0, let targetAddr = res else { return nil }
        defer { freeaddrinfo(res) }
        
        let sock = socket(targetAddr.pointee.ai_family, targetAddr.pointee.ai_socktype, targetAddr.pointee.ai_protocol)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        let flags = fcntl(sock, F_GETFL, 0)
        fcntl(sock, F_SETFL, flags | O_NONBLOCK)
        
        let connectResult = connect(sock, targetAddr.pointee.ai_addr, targetAddr.pointee.ai_addrlen)
        if connectResult < 0 {
            if errno == EINPROGRESS {
                var fdset = fd_set()
                fdSet(sock, set: &fdset)
                
                let sec = Int(timeoutSeconds)
                let usec = Int32((timeoutSeconds - Double(sec)) * 1_000_000)
                var tv = timeval(tv_sec: sec, tv_usec: usec)
                
                let selectResult = select(sock + 1, nil, &fdset, nil, &tv)
                if selectResult <= 0 {
                    return nil
                }
                
                var so_error: Int32 = 0
                var len = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &so_error, &len)
                if so_error != 0 { return nil }
            } else {
                return nil
            }
        }
        
        let endTime = DispatchTime.now()
        let elapsedNanos = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let latencyMs = Double(elapsedNanos) / 1_000_000.0
        return max(1, Int(round(latencyMs)))
    }
    
    private static func fdSet(_ fd: Int32, set: inout fd_set) {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask: Int32 = 1 << bitOffset
        switch intOffset {
        case 0: set.fds_bits.0 |= mask
        case 1: set.fds_bits.1 |= mask
        case 2: set.fds_bits.2 |= mask
        case 3: set.fds_bits.3 |= mask
        case 4: set.fds_bits.4 |= mask
        case 5: set.fds_bits.5 |= mask
        case 6: set.fds_bits.6 |= mask
        case 7: set.fds_bits.7 |= mask
        case 8: set.fds_bits.8 |= mask
        case 9: set.fds_bits.9 |= mask
        case 10: set.fds_bits.10 |= mask
        case 11: set.fds_bits.11 |= mask
        case 12: set.fds_bits.12 |= mask
        case 13: set.fds_bits.13 |= mask
        case 14: set.fds_bits.14 |= mask
        case 15: set.fds_bits.15 |= mask
        default: break
        }
    }
}
