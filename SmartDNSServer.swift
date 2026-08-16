import Foundation

public enum ServerRegion: String, CaseIterable, Codable {
    case ukAndEurope = "UK & Europe"
    case northAmerica = "North America"
    case asiaPacific = "Asia Pacific"
    case middleEastAndAfrica = "Middle East & Africa"
    case latinAmerica = "Latin America"
}

public struct SmartDNSServer: Identifiable, Hashable, Codable, Equatable {
    public let id: String
    public let city: String
    public let country: String
    public let flag: String
    public let ip: String
    public let region: ServerRegion
    
    public var displayName: String {
        "\(flag) \(city), \(country)"
    }
    
    public var shortName: String {
        "\(flag) \(city)"
    }
}

public struct ServerPairPreset: Identifiable, Hashable, Codable, Equatable {
    public let id: String
    public let name: String
    public let primary: SmartDNSServer
    public let secondary: SmartDNSServer
    public var isCustom: Bool
    
    public init(id: String, name: String, primary: SmartDNSServer, secondary: SmartDNSServer, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.primary = primary
        self.secondary = secondary
        self.isCustom = isCustom
    }
}

public struct FastDNSPreset: Identifiable, Hashable, Codable, Equatable {
    public let id: String
    public let name: String
    public let icon: String
    public let systemIcon: String
    public let primaryIP: String
    public let secondaryIP: String
    public let description: String
    
    public var ips: [String] {
        [primaryIP, secondaryIP]
    }
    
    public var formattedIPs: String {
        "\(primaryIP) / \(secondaryIP)"
    }
    
    public init(id: String, name: String, icon: String, systemIcon: String, primaryIP: String, secondaryIP: String, description: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemIcon = systemIcon
        self.primaryIP = primaryIP
        self.secondaryIP = secondaryIP
        self.description = description
    }
}

public struct FastDNSCatalog {
    public static let cloudflare = FastDNSPreset(
        id: "cloudflare",
        name: "Cloudflare",
        icon: "⚡",
        systemIcon: "bolt.fill",
        primaryIP: "1.1.1.1",
        secondaryIP: "1.0.0.1",
        description: "Consistently ranks #1 in global speed tests with a strong focus on user privacy."
    )
    
    public static let google = FastDNSPreset(
        id: "google",
        name: "Google",
        icon: "🌐",
        systemIcon: "globe",
        primaryIP: "8.8.8.8",
        secondaryIP: "8.8.4.4",
        description: "Highly stable and fast, though it logs query data for analytics."
    )
    
    public static let quad9 = FastDNSPreset(
        id: "quad9",
        name: "Quad9",
        icon: "🛡️",
        systemIcon: "shield.fill",
        primaryIP: "9.9.9.9",
        secondaryIP: "149.112.112.112",
        description: "Balances fast response times with automated malware blocking."
    )
    
    public static let allPresets: [FastDNSPreset] = [
        cloudflare,
        google,
        quad9
    ]
    
    public static func findPreset(byId id: String) -> FastDNSPreset? {
        allPresets.first(where: { $0.id == id })
    }
    
    public static func findPreset(matchingIPs ips: [String]) -> FastDNSPreset? {
        guard !ips.isEmpty else { return nil }
        return allPresets.first { preset in
            ips.allSatisfy { preset.ips.contains($0) }
        }
    }
    
    public static func provider(forIP ip: String) -> FastDNSPreset? {
        allPresets.first { $0.ips.contains(ip) }
    }
}

public struct SmartDNSCatalog {
    // European & UK Servers
    public static let london = SmartDNSServer(id: "uk_london", city: "London", country: "United Kingdom", flag: "🇬🇧", ip: "35.178.60.174", region: .ukAndEurope)
    public static let amsterdam = SmartDNSServer(id: "nl_amsterdam", city: "Amsterdam", country: "Netherlands", flag: "🇳🇱", ip: "46.166.189.68", region: .ukAndEurope)
    public static let frankfurt = SmartDNSServer(id: "de_frankfurt", city: "Frankfurt", country: "Germany", flag: "🇩🇪", ip: "54.93.173.153", region: .ukAndEurope)
    public static let paris = SmartDNSServer(id: "fr_paris", city: "Paris", country: "France", flag: "🇫🇷", ip: "45.77.61.165", region: .ukAndEurope)
    public static let dublin = SmartDNSServer(id: "ie_dublin", city: "Dublin", country: "Ireland", flag: "🇮🇪", ip: "54.229.171.243", region: .ukAndEurope)
    public static let copenhagen = SmartDNSServer(id: "dk_copenhagen", city: "Copenhagen", country: "Denmark", flag: "🇩🇰", ip: "82.103.129.72", region: .ukAndEurope)
    public static let madrid = SmartDNSServer(id: "es_madrid", city: "Madrid", country: "Spain", flag: "🇪🇸", ip: "185.93.3.163", region: .ukAndEurope)
    public static let milan = SmartDNSServer(id: "it_milan", city: "Milan", country: "Italy", flag: "🇮🇹", ip: "95.141.39.236", region: .ukAndEurope)
    public static let stockholm = SmartDNSServer(id: "se_stockholm", city: "Stockholm", country: "Sweden", flag: "🇸🇪", ip: "46.246.29.69", region: .ukAndEurope)
    public static let zurich = SmartDNSServer(id: "ch_zurich", city: "Zurich", country: "Switzerland", flag: "🇨🇭", ip: "81.17.17.170", region: .ukAndEurope)
    public static let istanbul = SmartDNSServer(id: "tr_istanbul", city: "Istanbul", country: "Turkey", flag: "🇹🇷", ip: "212.68.54.219", region: .ukAndEurope)

    // North America
    public static let usVirginia = SmartDNSServer(id: "us_virginia", city: "N. Virginia (US East)", country: "United States", flag: "🇺🇸", ip: "23.21.43.50", region: .northAmerica)
    public static let usNewJersey = SmartDNSServer(id: "us_newjersey", city: "New Jersey (US East)", country: "United States", flag: "🇺🇸", ip: "149.28.40.219", region: .northAmerica)
    public static let usMiami = SmartDNSServer(id: "us_miami", city: "Miami (US East)", country: "United States", flag: "🇺🇸", ip: "149.28.105.215", region: .northAmerica)
    public static let usChicago = SmartDNSServer(id: "us_chicago", city: "Chicago (US Central)", country: "United States", flag: "🇺🇸", ip: "107.191.48.176", region: .northAmerica)
    public static let usAtlanta = SmartDNSServer(id: "us_atlanta", city: "Atlanta (US Central)", country: "United States", flag: "🇺🇸", ip: "45.32.218.29", region: .northAmerica)
    public static let usDallas = SmartDNSServer(id: "us_dallas", city: "Dallas (US Central)", country: "United States", flag: "🇺🇸", ip: "169.53.235.135", region: .northAmerica)
    public static let usLosAngeles1 = SmartDNSServer(id: "us_la1", city: "Los Angeles 1 (US West)", country: "United States", flag: "🇺🇸", ip: "54.183.15.10", region: .northAmerica)
    public static let usLosAngeles2 = SmartDNSServer(id: "us_la2", city: "Los Angeles 2 (US West)", country: "United States", flag: "🇺🇸", ip: "149.28.65.242", region: .northAmerica)
    public static let usSeattle = SmartDNSServer(id: "us_seattle", city: "Seattle (US West)", country: "United States", flag: "🇺🇸", ip: "45.77.215.146", region: .northAmerica)
    public static let caMontreal = SmartDNSServer(id: "ca_montreal", city: "Montreal", country: "Canada", flag: "🇨🇦", ip: "169.54.78.85", region: .northAmerica)
    public static let caToronto = SmartDNSServer(id: "ca_toronto", city: "Toronto", country: "Canada", flag: "🇨🇦", ip: "169.53.182.120", region: .northAmerica)
    public static let caVancouver = SmartDNSServer(id: "ca_vancouver", city: "Vancouver", country: "Canada", flag: "🇨🇦", ip: "67.231.17.253", region: .northAmerica)
    public static let mxMexicoCity = SmartDNSServer(id: "mx_mexico", city: "Mexico City", country: "Mexico", flag: "🇲🇽", ip: "216.238.71.110", region: .northAmerica)

    // Asia Pacific
    public static let seoul = SmartDNSServer(id: "kr_seoul", city: "Seoul", country: "South Korea", flag: "🇰🇷", ip: "13.125.194.42", region: .asiaPacific)
    public static let tokyo = SmartDNSServer(id: "jp_tokyo", city: "Tokyo", country: "Japan", flag: "🇯🇵", ip: "54.64.107.105", region: .asiaPacific)
    public static let singapore = SmartDNSServer(id: "sg_singapore", city: "Singapore", country: "Singapore", flag: "🇸🇬", ip: "54.255.130.140", region: .asiaPacific)
    public static let inMumbai = SmartDNSServer(id: "in_mumbai", city: "Mumbai", country: "India", flag: "🇮🇳", ip: "35.154.249.83", region: .asiaPacific)
    public static let inChennai = SmartDNSServer(id: "in_chennai", city: "Chennai", country: "India", flag: "🇮🇳", ip: "169.38.73.5", region: .asiaPacific)
    public static let auSydney = SmartDNSServer(id: "au_sydney", city: "Sydney", country: "Australia", flag: "🇦🇺", ip: "54.66.128.66", region: .asiaPacific)
    public static let auMelbourne = SmartDNSServer(id: "au_melbourne", city: "Melbourne", country: "Australia", flag: "🇦🇺", ip: "118.127.62.179", region: .asiaPacific)
    public static let nzAuckland = SmartDNSServer(id: "nz_auckland", city: "Auckland", country: "New Zealand", flag: "🇳🇿", ip: "223.165.64.97", region: .asiaPacific)

    // Middle East & Africa
    public static let uaeDubai = SmartDNSServer(id: "ae_dubai", city: "Dubai", country: "UAE", flag: "🇦🇪", ip: "45.9.250.164", region: .middleEastAndAfrica)
    public static let ilRoshHaayin = SmartDNSServer(id: "il_rosh", city: "Rosh Haayin", country: "Israel", flag: "🇮🇱", ip: "195.28.181.161", region: .middleEastAndAfrica)
    public static let saSouthAfrica1 = SmartDNSServer(id: "za_sa1", city: "Johannesburg 1", country: "South Africa", flag: "🇿🇦", ip: "102.135.163.26", region: .middleEastAndAfrica)
    public static let saSouthAfrica2 = SmartDNSServer(id: "za_sa2", city: "Johannesburg 2", country: "South Africa", flag: "🇿🇦", ip: "129.232.164.26", region: .middleEastAndAfrica)

    // Latin America
    public static let brSaoPaulo = SmartDNSServer(id: "br_saopaulo", city: "Sao Paulo", country: "Brazil", flag: "🇧🇷", ip: "54.94.226.225", region: .latinAmerica)

    // All available servers
    public static let allServers: [SmartDNSServer] = [
        // UK & Europe First
        london, amsterdam, frankfurt, paris, dublin, copenhagen, madrid, milan, stockholm, zurich, istanbul,
        // North America
        usVirginia, usNewJersey, usMiami, usChicago, usAtlanta, usDallas, usLosAngeles1, usLosAngeles2, usSeattle, caMontreal, caToronto, caVancouver, mxMexicoCity,
        // Asia Pacific
        seoul, tokyo, singapore, inMumbai, inChennai, auSydney, auMelbourne, nzAuckland,
        // Middle East & Africa
        uaeDubai, ilRoshHaayin, saSouthAfrica1, saSouthAfrica2,
        // Latin America
        brSaoPaulo
    ]

    // Curated paired presets
    public static let presets: [ServerPairPreset] = [
        ServerPairPreset(id: "london_frankfurt", name: "🇬🇧 London + 🇩🇪 Frankfurt", primary: london, secondary: frankfurt),
        ServerPairPreset(id: "london_paris", name: "🇬🇧 London + 🇫🇷 Paris", primary: london, secondary: paris),
        ServerPairPreset(id: "london_amsterdam", name: "🇬🇧 London + 🇳🇱 Amsterdam", primary: london, secondary: amsterdam),
        ServerPairPreset(id: "london_dublin", name: "🇬🇧 London + 🇮🇪 Dublin", primary: london, secondary: dublin),
        ServerPairPreset(id: "amsterdam_seoul", name: "🇳🇱 Amsterdam + 🇰🇷 Seoul", primary: amsterdam, secondary: seoul),
        ServerPairPreset(id: "us_copenhagen", name: "🇺🇸 US East + 🇩🇰 Copenhagen", primary: usVirginia, secondary: copenhagen),
        ServerPairPreset(id: "frankfurt_zurich", name: "🇩🇪 Frankfurt + 🇨🇭 Zurich", primary: frankfurt, secondary: zurich),
        ServerPairPreset(id: "madrid_milan", name: "🇪🇸 Madrid + 🇮🇹 Milan", primary: madrid, secondary: milan)
    ]

    public static func findServer(byIP ip: String) -> SmartDNSServer? {
        allServers.first(where: { $0.ip == ip })
    }

    public static func findServer(byId id: String) -> SmartDNSServer? {
        allServers.first(where: { $0.id == id })
    }
}
