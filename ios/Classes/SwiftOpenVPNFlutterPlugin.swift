import Flutter
import UIKit
import NetworkExtension

@available(iOS 14.0, *)
public class SwiftOpenVPNFlutterPlugin: NSObject, FlutterPlugin {
    private static var utils : VPNUtils! = VPNUtils()
    
    private static var EVENT_CHANNEL_VPN_STAGE = "id.laskarmedia.openvpn_flutter/vpnstage"
    private static var METHOD_CHANNEL_VPN_CONTROL = "id.laskarmedia.openvpn_flutter/vpncontrol"
     
    public static var stage: FlutterEventSink?
    private var initialized : Bool = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftOpenVPNFlutterPlugin()
        instance.onRegister(registrar)
    }
    
    public func onRegister(_ registrar: FlutterPluginRegistrar){
        let vpnControlM = FlutterMethodChannel(name: SwiftOpenVPNFlutterPlugin.METHOD_CHANNEL_VPN_CONTROL, binaryMessenger: registrar.messenger())
        let vpnStageE = FlutterEventChannel(name: SwiftOpenVPNFlutterPlugin.EVENT_CHANNEL_VPN_STAGE, binaryMessenger: registrar.messenger())
        
        vpnStageE.setStreamHandler(StageHandler())
        vpnControlM.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "status":
                SwiftOpenVPNFlutterPlugin.utils.getTraffictStats()
                result(UserDefaults.init(suiteName: SwiftOpenVPNFlutterPlugin.utils.groupIdentifier)?.string(forKey: "connectionUpdate"))
                break;
            case "stage":
                result(SwiftOpenVPNFlutterPlugin.utils.currentStatus())
                break;
            case "initialize":
                let providerBundleIdentifier: String? = (call.arguments as? [String: Any])?["providerBundleIdentifier"] as? String
                let localizedDescription: String? = (call.arguments as? [String: Any])?["localizedDescription"] as? String
                let groupIdentifier: String? = (call.arguments as? [String: Any])?["groupIdentifier"] as? String
                if providerBundleIdentifier == nil  {
                    result(FlutterError(code: "-2",
                                        message: "providerBundleIdentifier content empty or null",
                                        details: nil));
                    return;
                }
                if localizedDescription == nil  {
                    result(FlutterError(code: "-3",
                                        message: "localizedDescription content empty or null",
                                        details: nil));
                    return;
                }
                if groupIdentifier == nil  {
                    result(FlutterError(code: "-4",
                                        message: "groupIdentifier content empty or null",
                                        details: nil));
                    return;
                }
                SwiftOpenVPNFlutterPlugin.utils.groupIdentifier = groupIdentifier
                SwiftOpenVPNFlutterPlugin.utils.localizedDescription = localizedDescription
                SwiftOpenVPNFlutterPlugin.utils.providerBundleIdentifier = providerBundleIdentifier
                SwiftOpenVPNFlutterPlugin.utils.loadProviderManager{(err:Error?) in
                    if err == nil{
                        result(SwiftOpenVPNFlutterPlugin.utils.currentStatus())
                    }else{
                        result(FlutterError(code: "-4", message: err?.localizedDescription, details: err?.localizedDescription));
                    }
                }
                self.initialized = true
                break;
            case "disconnect":
                SwiftOpenVPNFlutterPlugin.utils.stopVPN()
                break;
            case "connect":
                if !self.initialized {
                    result(FlutterError(code: "-1",
                                        message: "VPNEngine need to be initialize",
                                        details: nil));
                }
                let config: String? = (call.arguments as? [String : Any])? ["config"] as? String
                let username: String? = (call.arguments as? [String : Any])? ["username"] as? String
                let password: String? = (call.arguments as? [String : Any])? ["password"] as? String
                let serverAddress: String? = (call.arguments as? [String : Any])? ["server_address"] as? String
                if config == nil{
                    result(FlutterError(code: "-2",
                                        message:"Config is empty or nulled",
                                        details: "Config can't be nulled"))
                    return
                }
                
                SwiftOpenVPNFlutterPlugin.utils.configureVPN(config: config, username: username, password: password, serverAddress: serverAddress, completion: {(success:Error?) -> Void in
                    if(success == nil){
                        result(nil)
                    }else{
                        result(FlutterError(code: "99",
                                            message: "permission denied",
                                            details: success?.localizedDescription))
                    }
                })
                break;
            case "dispose":
                self.initialized = false
            default:
                break;
            }
        })
    }
    
    
    class StageHandler: NSObject, FlutterStreamHandler {
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            SwiftOpenVPNFlutterPlugin.utils.stage = events
            return nil
        }
        
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            SwiftOpenVPNFlutterPlugin.utils.stage = nil
            return nil
        }
    }
    
    
}


@available(iOS 9.0, *)
class VPNUtils {
    var providerManager: NETunnelProviderManager!
    var providerBundleIdentifier : String?
    var localizedDescription : String?
    var groupIdentifier : String?
    var stage : FlutterEventSink!
    var vpnStageObserver : NSObjectProtocol?
    
    func loadProviderManager(completion:@escaping (_ error : Error?) -> Void)  {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error)  in
            if error == nil {
                self.providerManager = managers?.first ?? NETunnelProviderManager()
                completion(nil)
            } else {
                completion(error)
            }
        }
    }
    
    func onVpnStatusChanged(notification : NEVPNStatus) {
        switch notification {
        case NEVPNStatus.connected:
            stage?("connected")
            break;
        case NEVPNStatus.connecting:
            stage?("connecting")
            break;
        case NEVPNStatus.disconnected:
            stage?("disconnected")
            break;
        case NEVPNStatus.disconnecting:
            stage?("disconnecting")
            break;
        case NEVPNStatus.invalid:
            stage?("invalid")
            break;
        case NEVPNStatus.reasserting:
            stage?("reasserting")
            break;
        default:
            stage?("null")
            break;
        }
    }
    
    func onVpnStatusChangedString(notification : NEVPNStatus?) -> String?{
        if notification == nil {
            return "disconnected"
        }
        switch notification! {
        case NEVPNStatus.connected:
            return "connected";
        case NEVPNStatus.connecting:
            return "connecting";
        case NEVPNStatus.disconnected:
            return "disconnected";
        case NEVPNStatus.disconnecting:
            return "disconnecting";
        case NEVPNStatus.invalid:
            return "invalid";
        case NEVPNStatus.reasserting:
            return "reasserting";
        default:
            return "";
        }
    }
    
    func currentStatus() -> String? {
        if self.providerManager != nil {
            return onVpnStatusChangedString(notification: self.providerManager.connection.status)}
        else{
            return "disconnected"
        }
    }

    @available(iOS 14.0, *)
    func configureVPN(config: String?, username : String?,password : String?,serverAddress : String?,completion:@escaping (_ error : Error?) -> Void) {
        let configData = config
        self.providerManager?.loadFromPreferences { error in
            if error == nil {
                let tunnelProtocol = NETunnelProviderProtocol()
                tunnelProtocol.serverAddress = serverAddress ?? ""
                tunnelProtocol.providerBundleIdentifier = self.providerBundleIdentifier
                let nullData = "".data(using: .utf8)
                tunnelProtocol.providerConfiguration = [
                    "config": configData?.data(using: .utf8) ?? nullData!,
                    "groupIdentifier": self.groupIdentifier?.data(using: .utf8) ?? nullData!,
                    "username" : username?.data(using: .utf8) ?? nullData!,
                    "password" : password?.data(using: .utf8) ?? nullData!
                ]
                tunnelProtocol.disconnectOnSleep = false
                
                var onDemandRules: [NEOnDemandRule] = []
                
                let killSwitchRule = NEOnDemandRuleConnect()
                killSwitchRule.interfaceTypeMatch = .any
                
                onDemandRules.append(killSwitchRule)
                
                print("tunnelProtocol.serverAddress : ", (serverAddress ?? "Not Found"))
                
                if let serverAddress = serverAddress, !serverAddress.isEmpty {
                    let evaluationRule = NEEvaluateConnectionRule(matchDomains: TLDList.tlds, andAction: .connectIfNeeded)
                    evaluationRule.useDNSServers = [serverAddress]
                    
                    let onDemandDNSRule = NEOnDemandRuleEvaluateConnection()
                    onDemandDNSRule.connectionRules = [evaluationRule]
                    onDemandDNSRule.interfaceTypeMatch = .any
                    
                    
                    onDemandRules.append(onDemandDNSRule)
                }
                
                tunnelProtocol.includeAllNetworks = true
                
                self.providerManager.isOnDemandEnabled = true
                
                self.providerManager.onDemandRules = onDemandRules
                
                self.providerManager.protocolConfiguration = tunnelProtocol
                self.providerManager.localizedDescription = self.localizedDescription // the title of the VPN profile which will appear on Settings
                self.providerManager.isEnabled = true

//                 if let tunnelProtocol = self.providerManager.protocolConfiguration as? NETunnelProviderProtocol {
//
//                     let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "3.99.247.188")
//                     networkSettings.ipv4Settings = NEIPv4Settings(addresses: ["3.99.247.188"], subnetMasks: ["255.255.255.0"])
//                     networkSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
//                     networkSettings.ipv4Settings?.excludedRoutes = []
//
// //                    networkSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
//                     self.setTunnelNetworkSettings(networkSettings) { error in
//                         if let error = error {
//                             print("Failed to set tunnel network settings: \(error)")
//                             completion(error)
//                             return
//                         }
//                         completion(nil)
//                         // Start handling packets
// //                        self.startHandlingPackets()
//                     }
//                 }

                self.providerManager.saveToPreferences(completionHandler: { (error) in
                    if error == nil  {
                        self.providerManager.loadFromPreferences(completionHandler: { (error) in
                            if error != nil {
                                completion(error);
                                return;
                            }
                            do {
                                if self.vpnStageObserver != nil {
                                    NotificationCenter.default.removeObserver(self.vpnStageObserver!,
                                                                              name: NSNotification.Name.NEVPNStatusDidChange,
                                                                              object: nil)
                                }
                                self.vpnStageObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange,
                                                                                               object: nil ,
                                                                                               queue: nil) { [weak self] notification in
                                    let nevpnconn = notification.object as! NEVPNConnection
                                    let status = nevpnconn.status
                                    self?.onVpnStatusChanged(notification: status)
                                }
                                
                                if username != nil && password != nil{
                                    var options: [String : NSObject] = [
                                        "username": username! as NSString,
                                        "password": password! as NSString
                                    ]
                                    if let serverAddress = serverAddress, !serverAddress.isEmpty {
                                        options["serverAddress"] = serverAddress as NSString
                                    }
                                    try self.providerManager.connection.startVPNTunnel(options: options)
                                }else{
                                    
                                    if let serverAddress = serverAddress, !serverAddress.isEmpty {
                                        var options: [String : NSObject] = [
                                            "serverAddress": serverAddress as NSString
                                        ]
                                    
                                        try self.providerManager.connection.startVPNTunnel(options: options)
                                    } else {
                                        try self.providerManager.connection.startVPNTunnel()
                                    }
                                }
                                completion(nil);
                            } catch let error {
                                self.stopVPN()
                                print("Error info: \(error)")
                                completion(error);
                            }
                        })
                    } else {
                        completion(error);
                    }
                })
                
                if let serverAddress = serverAddress, !serverAddress.isEmpty {
                    let dnsSettings = NEDNSOverTLSSettings(servers: [serverAddress])
                    dnsSettings.matchDomains = TLDList.tlds
                    NEDNSSettingsManager.shared().dnsSettings = dnsSettings
                    NEDNSSettingsManager.shared().saveToPreferences { error in
                        // ... (error handling)
                    }
                }
                
//                let proxyManager = NEDNSProxyManager.shared()
//                
//                proxyManager.loadFromPreferences{ (error) in
//                    
//                    if let error = error {
//                        print("Error loading preferences: \(error)")
//                        return
//                    }
//                    
//                    let proxySettings = NEProxySettings()
//                    let proxyServer = NEProxyServer(address: serverAddress ?? "", port: 53)
//                        
//                    proxySettings.httpEnabled = true
//                    proxySettings.httpServer = proxyServer
//                    proxySettings.httpsEnabled = true
//                    proxySettings.httpsServer = proxyServer
//                
//                    
//                    let dnsProtocol = NEDNSProxyProviderProtocol()
//                    dnsProtocol.serverAddress = serverAddress
//                    dnsProtocol.providerBundleIdentifier = self.providerBundleIdentifier
//                    dnsProtocol.disconnectOnSleep = false
//                    dnsProtocol.proxySettings = proxySettings
//                    
//                    proxyManager.providerProtocol = dnsProtocol
//                    proxyManager.isEnabled = true
//                
//                    proxyManager.saveToPreferences { (error) in
//                        if let error = error {
//                            print("Error saving preferences: \(error)")
//                        } else {
//                            print("DNS Proxy configured successfully!")
//                        }
//                    }
//                    
//                }
                
            }
        }
        
        
    }
    
    @available(iOS 14.0, *)
    func stopVPN() {
        
        self.providerManager.isOnDemandEnabled = false
        self.providerManager.saveToPreferences();
        self.providerManager.connection.stopVPNTunnel();
        
        NEDNSSettingsManager.shared().loadFromPreferences { error in
            if let error = error {
                // Handle error loading preferences
                return
            }
            
            // Check if custom DNS settings are currently active
            if NEDNSSettingsManager.shared().dnsSettings != nil {
                // Remove any custom DNS settings (this should revert to system defaults)
                NEDNSSettingsManager.shared().dnsSettings = nil

                NEDNSSettingsManager.shared().saveToPreferences { error in
                    if let error = error {}
                }
            }
        }
        
        stopDNSProxy()
        // Clear the network settings
//        setTunnelNetworkSettings(nil) { error in
//            if let error = error {
//                print("Error clearing tunnel network settings: \(error)")
//            }
//        }
    }
    
    func stopDNSProxy() {
//        let proxyManager = NEDNSProxyManager.shared()
//        
//        proxyManager.loadFromPreferences { (error) in
//            if let error = error {
//                print("Error loading preferences: \(error)")
//                return
//            }
//            
//            do {
//                try proxyManager.stopProxy(with: .userInitiated) {
//                    print("DNS Proxy stopped successfully!")
//                }
//            } catch let stopError {
//                print("Failed to stop DNS Proxy: \(stopError)")
//            }
//        }
    }
    
    func getTraffictStats(){
        if let session = self.providerManager?.connection as? NETunnelProviderSession {
            do {
                try session.sendProviderMessage("OPENVPN_STATS".data(using: .utf8)!) {(data) in
                    //Do nothing
                }
            } catch {
            // some error
            }
        }
    }
}

class TLDList {
    static let tlds = [
        "*.aaa",
        "*.aarp",
        "*.abarth",
        "*.abb",
        "*.abbott",
        "*.abbvie",
        "*.abc",
        "*.able",
        "*.abogado",
        "*.abudhabi",
        "*.ac",
        "*.academy",
        "*.accenture",
        "*.accountant",
        "*.accountants",
        "*.aco",
        "*.active",
        "*.actor",
        "*.ad",
        "*.adac",
        "*.ads",
        "*.adult",
        "*.ae",
        "*.aeg",
        "*.aero",
        "*.aetna",
        "*.af",
        "*.afamilycompany",
        "*.afl",
        "*.africa",
        "*.ag",
        "*.agakhan",
        "*.agency",
        "*.ai",
        "*.aig",
        "*.aigo",
        "*.airbus",
        "*.airforce",
        "*.airtel",
        "*.akdn",
        "*.al",
        "*.alfaromeo",
        "*.alibaba",
        "*.alipay",
        "*.allfinanz",
        "*.allstate",
        "*.ally",
        "*.alsace",
        "*.alstom",
        "*.am",
        "*.americanexpress",
        "*.americanfamily",
        "*.amex",
        "*.amfam",
        "*.amica",
        "*.amsterdam",
        "*.analytics",
        "*.android",
        "*.anquan",
        "*.anz",
        "*.ao",
        "*.aol",
        "*.apartments",
        "*.app",
        "*.apple",
        "*.aq",
        "*.aquarelle",
        "*.ar",
        "*.arab",
        "*.aramco",
        "*.archi",
        "*.army",
        "*.arpa",
        "*.art",
        "*.arte",
        "*.as",
        "*.asda",
        "*.asia",
        "*.associates",
        "*.at",
        "*.athleta",
        "*.attorney",
        "*.au",
        "*.auction",
        "*.audi",
        "*.audible",
        "*.audio",
        "*.auspost",
        "*.author",
        "*.auto",
        "*.autos",
        "*.avianca",
        "*.aw",
        "*.aws",
        "*.ax",
        "*.axa",
        "*.az",
        "*.azure",
        "*.ba",
        "*.baby",
        "*.baidu",
        "*.banamex",
        "*.bananarepublic",
        "*.band",
        "*.bank",
        "*.bar",
        "*.barcelona",
        "*.barclaycard",
        "*.barclays",
        "*.barefoot",
        "*.bargains",
        "*.baseball",
        "*.basketball",
        "*.bauhaus",
        "*.bayern",
        "*.bb",
        "*.bbc",
        "*.bbt",
        "*.bbva",
        "*.bcg",
        "*.bcn",
        "*.bd",
        "*.be",
        "*.beats",
        "*.beauty",
        "*.beer",
        "*.bentley",
        "*.berlin",
        "*.best",
        "*.bestbuy",
        "*.bet",
        "*.bf",
        "*.bg",
        "*.bh",
        "*.bharti",
        "*.bi",
        "*.bible",
        "*.bid",
        "*.bike",
        "*.bing",
        "*.bingo",
        "*.bio",
        "*.biz",
        "*.bj",
        "*.black",
        "*.blackfriday",
        "*.blanco",
        "*.blockbuster",
        "*.blog",
        "*.bloomberg",
        "*.blue",
        "*.bm",
        "*.bms",
        "*.bmw",
        "*.bn",
        "*.bnl",
        "*.bnpparibas",
        "*.bo",
        "*.boats",
        "*.boehringer",
        "*.bofa",
        "*.bom",
        "*.bond",
        "*.boo",
        "*.book",
        "*.booking",
        "*.bosch",
        "*.bostik",
        "*.boston",
        "*.bot",
        "*.boutique",
        "*.box",
        "*.br",
        "*.bradesco",
        "*.bridgestone",
        "*.broadway",
        "*.broker",
        "*.brother",
        "*.brussels",
        "*.bs",
        "*.bt",
        "*.budapest",
        "*.bugatti",
        "*.build",
        "*.builders",
        "*.business",
        "*.buy",
        "*.buzz",
        "*.bv",
        "*.bw",
        "*.by",
        "*.bz",
        "*.bzh",
        "*.ca",
        "*.cab",
        "*.cafe",
        "*.cal",
        "*.call",
        "*.calvinklein",
        "*.cam",
        "*.camera",
        "*.camp",
        "*.cancerresearch",
        "*.canon",
        "*.capetown",
        "*.capital",
        "*.capitalone",
        "*.car",
        "*.caravan",
        "*.cards",
        "*.care",
        "*.career",
        "*.careers",
        "*.cars",
        "*.cartier",
        "*.casa",
        "*.case",
        "*.caseih",
        "*.cash",
        "*.casino",
        "*.cat",
        "*.catering",
        "*.catholic",
        "*.cba",
        "*.cbn",
        "*.cbre",
        "*.cbs",
        "*.cc",
        "*.cd",
        "*.ceb",
        "*.center",
        "*.ceo",
        "*.cern",
        "*.cf",
        "*.cfa",
        "*.cfd",
        "*.cg",
        "*.ch",
        "*.chanel",
        "*.channel",
        "*.chase",
        "*.chat",
        "*.cheap",
        "*.chintai",
        "*.christmas",
        "*.chrome",
        "*.chrysler",
        "*.church",
        "*.ci",
        "*.cipriani",
        "*.circle",
        "*.cisco",
        "*.citadel",
        "*.citi",
        "*.citic",
        "*.city",
        "*.cityeats",
        "*.ck",
        "*.cl",
        "*.claims",
        "*.cleaning",
        "*.click",
        "*.clinic",
        "*.clinique",
        "*.clothing",
        "*.cloud",
        "*.club",
        "*.clubmed",
        "*.cm",
        "*.cn",
        "*.co",
        "*.coach",
        "*.codes",
        "*.coffee",
        "*.college",
        "*.cologne",
        "*.com",
        "*.comcast",
        "*.commbank",
        "*.community",
        "*.company",
        "*.compare",
        "*.computer",
        "*.comsec",
        "*.condos",
        "*.construction",
        "*.consulting",
        "*.contact",
        "*.contractors",
        "*.cooking",
        "*.cookingchannel",
        "*.cool",
        "*.coop",
        "*.corsica",
        "*.country",
        "*.coupon",
        "*.coupons",
        "*.courses",
        "*.cr",
        "*.credit",
        "*.creditcard",
        "*.creditunion",
        "*.cricket",
        "*.crown",
        "*.crs",
        "*.cruise",
        "*.cruises",
        "*.csc",
        "*.cu",
        "*.cuisinella",
        "*.cv",
        "*.cw",
        "*.cx",
        "*.cy",
        "*.cymru",
        "*.cyou",
        "*.cz",
        "*.dabur",
        "*.dad",
        "*.dance",
        "*.data",
        "*.date",
        "*.dating",
        "*.datsun",
        "*.day",
        "*.dclk",
        "*.dds",
        "*.de",
        "*.deal",
        "*.dealer",
        "*.deals",
        "*.degree",
        "*.delivery",
        "*.dell",
        "*.deloitte",
        "*.delta",
        "*.democrat",
        "*.dental",
        "*.dentist",
        "*.desi",
        "*.design",
        "*.dev",
        "*.dhl",
        "*.diamonds",
        "*.diet",
        "*.digital",
        "*.direct",
        "*.directory",
        "*.discount",
        "*.discover",
        "*.dish",
        "*.diy",
        "*.dj",
        "*.dk",
        "*.dm",
        "*.dnp",
        "*.do",
        "*.docs",
        "*.doctor",
        "*.dodge",
        "*.dog",
        "*.doha",
        "*.domains",
        "*.dot",
        "*.download",
        "*.drive",
        "*.dtv",
        "*.dubai",
        "*.duck",
        "*.dunlop",
        "*.duns",
        "*.dupont",
        "*.durban",
        "*.dvag",
        "*.dvr",
        "*.dz",
        "*.earth",
        "*.eat",
        "*.ec",
        "*.eco",
        "*.edeka",
        "*.edu",
        "*.education",
        "*.ee",
        "*.eg",
        "*.email",
        "*.emerck",
        "*.energy",
        "*.engineer",
        "*.engineering",
        "*.enterprises",
        "*.epost",
        "*.epson",
        "*.equipment",
        "*.er",
        "*.ericsson",
        "*.erni",
        "*.es",
        "*.esq",
        "*.estate",
        "*.esurance",
        "*.et",
        "*.etisalat",
        "*.eu",
        "*.eurovision",
        "*.eus",
        "*.events",
        "*.everbank",
        "*.exchange",
        "*.expert",
        "*.exposed",
        "*.express",
        "*.extraspace",
        "*.fage",
        "*.fail",
        "*.fairwinds",
        "*.faith",
        "*.family",
        "*.fan",
        "*.fans",
        "*.farm",
        "*.farmers",
        "*.fashion",
        "*.fast",
        "*.fedex",
        "*.feedback",
        "*.ferrari",
        "*.ferrero",
        "*.fi",
        "*.fiat",
        "*.fidelity",
        "*.fido",
        "*.film",
        "*.final",
        "*.finance",
        "*.financial",
        "*.fire",
        "*.firestone",
        "*.firmdale",
        "*.fish",
        "*.fishing",
        "*.fit",
        "*.fitness",
        "*.fj",
        "*.fk",
        "*.flickr",
        "*.flights",
        "*.flir",
        "*.florist",
        "*.flowers",
        "*.fly",
        "*.fm",
        "*.fo",
        "*.foo",
        "*.food",
        "*.foodnetwork",
        "*.football",
        "*.ford",
        "*.forex",
        "*.forsale",
        "*.forum",
        "*.foundation",
        "*.fox",
        "*.fr",
        "*.free",
        "*.fresenius",
        "*.frl",
        "*.frogans",
        "*.frontdoor",
        "*.frontier",
        "*.ftr",
        "*.fujitsu",
        "*.fujixerox",
        "*.fun",
        "*.fund",
        "*.furniture",
        "*.futbol",
        "*.fyi",
        "*.ga",
        "*.gal",
        "*.gallery",
        "*.gallo",
        "*.gallup",
        "*.game",
        "*.games",
        "*.gap",
        "*.garden",
        "*.gb",
        "*.gbiz",
        "*.gd",
        "*.gdn",
        "*.ge",
        "*.gea",
        "*.gent",
        "*.genting",
        "*.george",
        "*.gf",
        "*.gg",
        "*.ggee",
        "*.gh",
        "*.gi",
        "*.gift",
        "*.gifts",
        "*.gives",
        "*.giving",
        "*.gl",
        "*.glade",
        "*.glass",
        "*.gle",
        "*.global",
        "*.globo",
        "*.gm",
        "*.gmail",
        "*.gmbh",
        "*.gmo",
        "*.gmx",
        "*.gn",
        "*.godaddy",
        "*.gold",
        "*.goldpoint",
        "*.golf",
        "*.goo",
        "*.goodhands",
        "*.goodyear",
        "*.goog",
        "*.google",
        "*.gop",
        "*.got",
        "*.gov",
        "*.gp",
        "*.gq",
        "*.gr",
        "*.grainger",
        "*.graphics",
        "*.gratis",
        "*.green",
        "*.gripe",
        "*.grocery",
        "*.group",
        "*.gs",
        "*.gt",
        "*.gu",
        "*.guardian",
        "*.gucci",
        "*.guge",
        "*.guide",
        "*.guitars",
        "*.guru",
        "*.gw",
        "*.gy",
        "*.hair",
        "*.hamburg",
        "*.hangout",
        "*.haus",
        "*.hbo",
        "*.hdfc",
        "*.hdfcbank",
        "*.health",
        "*.healthcare",
        "*.help",
        "*.helsinki",
        "*.here",
        "*.hermes",
        "*.hgtv",
        "*.hiphop",
        "*.hisamitsu",
        "*.hitachi",
        "*.hiv",
        "*.hk",
        "*.hkt",
        "*.hm",
        "*.hn",
        "*.hockey",
        "*.holdings",
        "*.holiday",
        "*.homedepot",
        "*.homegoods",
        "*.homes",
        "*.homesense",
        "*.honda",
        "*.honeywell",
        "*.horse",
        "*.hospital",
        "*.host",
        "*.hosting",
        "*.hot",
        "*.hoteles",
        "*.hotels",
        "*.hotmail",
        "*.house",
        "*.how",
        "*.hr",
        "*.hsbc",
        "*.ht",
        "*.hu",
        "*.hughes",
        "*.hyatt",
        "*.hyundai",
        "*.ibm",
        "*.icbc",
        "*.ice",
        "*.icu",
        "*.id",
        "*.ie",
        "*.ieee",
        "*.ifm",
        "*.ikano",
        "*.il",
        "*.im",
        "*.imamat",
        "*.imdb",
        "*.immo",
        "*.immobilien",
        "*.in",
        "*.industries",
        "*.infiniti",
        "*.info",
        "*.ing",
        "*.ink",
        "*.institute",
        "*.insurance",
        "*.insure",
        "*.int",
        "*.intel",
        "*.international",
        "*.intuit",
        "*.investments",
        "*.io",
        "*.ipiranga",
        "*.iq",
        "*.ir",
        "*.irish",
        "*.is",
        "*.iselect",
        "*.ismaili",
        "*.ist",
        "*.istanbul",
        "*.it",
        "*.itau",
        "*.itv",
        "*.iveco",
        "*.iwc",
        "*.jaguar",
        "*.java",
        "*.jcb",
        "*.jcp",
        "*.je",
        "*.jeep",
        "*.jetzt",
        "*.jewelry",
        "*.jio",
        "*.jlc",
        "*.jll",
        "*.jm",
        "*.jmp",
        "*.jnj",
        "*.jo",
        "*.jobs",
        "*.joburg",
        "*.jot",
        "*.joy",
        "*.jp",
        "*.jpmorgan",
        "*.jprs",
        "*.juegos",
        "*.juniper",
        "*.kaufen",
        "*.kddi",
        "*.ke",
        "*.kerryhotels",
        "*.kerrylogistics",
        "*.kerryproperties",
        "*.kfh",
        "*.kg",
        "*.kh",
        "*.ki",
        "*.kia",
        "*.kim",
        "*.kinder",
        "*.kindle",
        "*.kitchen",
        "*.kiwi",
        "*.km",
        "*.kn",
        "*.koeln",
        "*.komatsu",
        "*.kosher",
        "*.kp",
        "*.kpmg",
        "*.kpn",
        "*.kr",
        "*.krd",
        "*.kred",
        "*.kuokgroup",
        "*.kw",
        "*.ky",
        "*.kyoto",
        "*.kz",
        "*.la",
        "*.lacaixa",
        "*.ladbrokes",
        "*.lamborghini",
        "*.lamer",
        "*.lancaster",
        "*.lancia",
        "*.lancome",
        "*.land",
        "*.landrover",
        "*.lanxess",
        "*.lasalle",
        "*.lat",
        "*.latino",
        "*.latrobe",
        "*.law",
        "*.lawyer",
        "*.lb",
        "*.lc",
        "*.lds",
        "*.lease",
        "*.leclerc",
        "*.lefrak",
        "*.legal",
        "*.lego",
        "*.lexus",
        "*.lgbt",
        "*.li",
        "*.liaison",
        "*.lidl",
        "*.life",
        "*.lifeinsurance",
        "*.lifestyle",
        "*.lighting",
        "*.like",
        "*.lilly",
        "*.limited",
        "*.limo",
        "*.lincoln",
        "*.linde",
        "*.link",
        "*.lipsy",
        "*.live",
        "*.living",
        "*.lixil",
        "*.lk",
        "*.llc",
        "*.loan",
        "*.loans",
        "*.locker",
        "*.locus",
        "*.loft",
        "*.lol",
        "*.london",
        "*.lotte",
        "*.lotto",
        "*.love",
        "*.lpl",
        "*.lplfinancial",
        "*.lr",
        "*.ls",
        "*.lt",
        "*.ltd",
        "*.ltda",
        "*.lu",
        "*.lundbeck",
        "*.lupin",
        "*.luxe",
        "*.luxury",
        "*.lv",
        "*.ly",
        "*.ma",
        "*.macys",
        "*.madrid",
        "*.maif",
        "*.maison",
        "*.makeup",
        "*.man",
        "*.management",
        "*.mango",
        "*.map",
        "*.market",
        "*.marketing",
        "*.markets",
        "*.marriott",
        "*.marshalls",
        "*.maserati",
        "*.mattel",
        "*.mba",
        "*.mc",
        "*.mckinsey",
        "*.md",
        "*.me",
        "*.med",
        "*.media",
        "*.meet",
        "*.melbourne",
        "*.meme",
        "*.memorial",
        "*.men",
        "*.menu",
        "*.merckmsd",
        "*.metlife",
        "*.mg",
        "*.mh",
        "*.miami",
        "*.microsoft",
        "*.mil",
        "*.mini",
        "*.mint",
        "*.mit",
        "*.mitsubishi",
        "*.mk",
        "*.ml",
        "*.mlb",
        "*.mls",
        "*.mm",
        "*.mma",
        "*.mn",
        "*.mo",
        "*.mobi",
        "*.mobile",
        "*.mobily",
        "*.moda",
        "*.moe",
        "*.moi",
        "*.mom",
        "*.monash",
        "*.money",
        "*.monster",
        "*.mopar",
        "*.mormon",
        "*.mortgage",
        "*.moscow",
        "*.moto",
        "*.motorcycles",
        "*.mov",
        "*.movie",
        "*.movistar",
        "*.mp",
        "*.mq",
        "*.mr",
        "*.ms",
        "*.msd",
        "*.mt",
        "*.mtn",
        "*.mtr",
        "*.mu",
        "*.museum",
        "*.mutual",
        "*.mv",
        "*.mw",
        "*.mx",
        "*.my",
        "*.mz",
        "*.na",
        "*.nab",
        "*.nadex",
        "*.nagoya",
        "*.name",
        "*.nationwide",
        "*.natura",
        "*.navy",
        "*.nba",
        "*.nc",
        "*.ne",
        "*.nec",
        "*.net",
        "*.netbank",
        "*.netflix",
        "*.network",
        "*.neustar",
        "*.new",
        "*.newholland",
        "*.news",
        "*.next",
        "*.nextdirect",
        "*.nexus",
        "*.nf",
        "*.nfl",
        "*.ng",
        "*.ngo",
        "*.nhk",
        "*.ni",
        "*.nico",
        "*.nike",
        "*.nikon",
        "*.ninja",
        "*.nissan",
        "*.nissay",
        "*.nl",
        "*.no",
        "*.nokia",
        "*.northwesternmutual",
        "*.norton",
        "*.now",
        "*.nowruz",
        "*.nowtv",
        "*.np",
        "*.nr",
        "*.nra",
        "*.nrw",
        "*.ntt",
        "*.nu",
        "*.nyc",
        "*.nz",
        "*.obi",
        "*.observer",
        "*.off",
        "*.office",
        "*.okinawa",
        "*.olayan",
        "*.olayangroup",
        "*.oldnavy",
        "*.ollo",
        "*.om",
        "*.omega",
        "*.one",
        "*.ong",
        "*.onl",
        "*.online",
        "*.onyourside",
        "*.ooo",
        "*.open",
        "*.oracle",
        "*.orange",
        "*.org",
        "*.organic",
        "*.origins",
        "*.osaka",
        "*.otsuka",
        "*.ott",
        "*.ovh",
        "*.pa",
        "*.page",
        "*.panasonic",
        "*.panerai",
        "*.paris",
        "*.pars",
        "*.partners",
        "*.parts",
        "*.party",
        "*.passagens",
        "*.pay",
        "*.pccw",
        "*.pe",
        "*.pet",
        "*.pf",
        "*.pfizer",
        "*.pg",
        "*.ph",
        "*.pharmacy",
        "*.phd",
        "*.philips",
        "*.phone",
        "*.photo",
        "*.photography",
        "*.photos",
        "*.physio",
        "*.piaget",
        "*.pics",
        "*.pictet",
        "*.pictures",
        "*.pid",
        "*.pin",
        "*.ping",
        "*.pink",
        "*.pioneer",
        "*.pizza",
        "*.pk",
        "*.pl",
        "*.place",
        "*.play",
        "*.playstation",
        "*.plumbing",
        "*.plus",
        "*.pm",
        "*.pn",
        "*.pnc",
        "*.pohl",
        "*.poker",
        "*.politie",
        "*.porn",
        "*.post",
        "*.pr",
        "*.pramerica",
        "*.praxi",
        "*.press",
        "*.prime",
        "*.pro",
        "*.prod",
        "*.productions",
        "*.prof",
        "*.progressive",
        "*.promo",
        "*.properties",
        "*.property",
        "*.protection",
        "*.pru",
        "*.prudential",
        "*.ps",
        "*.pt",
        "*.pub",
        "*.pw",
        "*.pwc",
        "*.py",
        "*.qa",
        "*.qpon",
        "*.quebec",
        "*.quest",
        "*.qvc",
        "*.racing",
        "*.radio",
        "*.raid",
        "*.re",
        "*.read",
        "*.realestate",
        "*.realtor",
        "*.realty",
        "*.recipes",
        "*.red",
        "*.redstone",
        "*.redumbrella",
        "*.rehab",
        "*.reise",
        "*.reisen",
        "*.reit",
        "*.reliance",
        "*.ren",
        "*.rent",
        "*.rentals",
        "*.repair",
        "*.report",
        "*.republican",
        "*.rest",
        "*.restaurant",
        "*.review",
        "*.reviews",
        "*.rexroth",
        "*.rich",
        "*.richardli",
        "*.ricoh",
        "*.rightathome",
        "*.ril",
        "*.rio",
        "*.rip",
        "*.rmit",
        "*.ro",
        "*.rocher",
        "*.rocks",
        "*.rodeo",
        "*.rogers",
        "*.room",
        "*.rs",
        "*.rsvp",
        "*.ru",
        "*.rugby",
        "*.ruhr",
        "*.run",
        "*.rw",
        "*.rwe",
        "*.ryukyu",
        "*.sa",
        "*.saarland",
        "*.safe",
        "*.safety",
        "*.sakura",
        "*.sale",
        "*.salon",
        "*.samsclub",
        "*.samsung",
        "*.sandvik",
        "*.sandvikcoromant",
        "*.sanofi",
        "*.sap",
        "*.sarl",
        "*.sas",
        "*.save",
        "*.saxo",
        "*.sb",
        "*.sbi",
        "*.sbs",
        "*.sc",
        "*.sca",
        "*.scb",
        "*.schaeffler",
        "*.schmidt",
        "*.scholarships",
        "*.school",
        "*.schule",
        "*.schwarz",
        "*.science",
        "*.scjohnson",
        "*.scor",
        "*.scot",
        "*.sd",
        "*.se",
        "*.search",
        "*.seat",
        "*.secure",
        "*.security",
        "*.seek",
        "*.select",
        "*.sener",
        "*.services",
        "*.ses",
        "*.seven",
        "*.sew",
        "*.sex",
        "*.sexy",
        "*.sfr",
        "*.sg",
        "*.sh",
        "*.shangrila",
        "*.sharp",
        "*.shaw",
        "*.shell",
        "*.shia",
        "*.shiksha",
        "*.shoes",
        "*.shop",
        "*.shopping",
        "*.shouji",
        "*.show",
        "*.showtime",
        "*.shriram",
        "*.si",
        "*.silk",
        "*.sina",
        "*.singles",
        "*.site",
        "*.sj",
        "*.sk",
        "*.ski",
        "*.skin",
        "*.sky",
        "*.skype",
        "*.sl",
        "*.sling",
        "*.sm",
        "*.smart",
        "*.smile",
        "*.sn",
        "*.sncf",
        "*.so",
        "*.soccer",
        "*.social",
        "*.softbank",
        "*.software",
        "*.sohu",
        "*.solar",
        "*.solutions",
        "*.song",
        "*.sony",
        "*.soy",
        "*.space",
        "*.spiegel",
        "*.sport",
        "*.spot",
        "*.spreadbetting",
        "*.sr",
        "*.srl",
        "*.srt",
        "*.st",
        "*.stada",
        "*.staples",
        "*.star",
        "*.starhub",
        "*.statebank",
        "*.statefarm",
        "*.statoil",
        "*.stc",
        "*.stcgroup",
        "*.stockholm",
        "*.storage",
        "*.store",
        "*.stream",
        "*.studio",
        "*.study",
        "*.style",
        "*.su",
        "*.sucks",
        "*.supplies",
        "*.supply",
        "*.support",
        "*.surf",
        "*.surgery",
        "*.suzuki",
        "*.sv",
        "*.swatch",
        "*.swiftcover",
        "*.swiss",
        "*.sx",
        "*.sy",
        "*.sydney",
        "*.symantec",
        "*.systems",
        "*.sz",
        "*.tab",
        "*.taipei",
        "*.talk",
        "*.taobao",
        "*.target",
        "*.tatamotors",
        "*.tatar",
        "*.tattoo",
        "*.tax",
        "*.taxi",
        "*.tc",
        "*.tci",
        "*.td",
        "*.tdk",
        "*.team",
        "*.tech",
        "*.technology",
        "*.tel",
        "*.telecity",
        "*.telefonica",
        "*.temasek",
        "*.tennis",
        "*.teva",
        "*.tf",
        "*.tg",
        "*.th",
        "*.thd",
        "*.theater",
        "*.theatre",
        "*.tiaa",
        "*.tickets",
        "*.tienda",
        "*.tiffany",
        "*.tips",
        "*.tires",
        "*.tirol",
        "*.tj",
        "*.tjmaxx",
        "*.tjx",
        "*.tk",
        "*.tkmaxx",
        "*.tl",
        "*.tm",
        "*.tmall",
        "*.tn",
        "*.to",
        "*.today",
        "*.tokyo",
        "*.tools",
        "*.top",
        "*.toray",
        "*.toshiba",
        "*.total",
        "*.tours",
        "*.town",
        "*.toyota",
        "*.toys",
        "*.tr",
        "*.trade",
        "*.trading",
        "*.training",
        "*.travel",
        "*.travelchannel",
        "*.travelers",
        "*.travelersinsurance",
        "*.trust",
        "*.trv",
        "*.tt",
        "*.tube",
        "*.tui",
        "*.tunes",
        "*.tushu",
        "*.tv",
        "*.tvs",
        "*.tw",
        "*.tz",
        "*.ua",
        "*.ubank",
        "*.ubs",
        "*.uconnect",
        "*.ug",
        "*.uk",
        "*.unicom",
        "*.university",
        "*.uno",
        "*.uol",
        "*.ups",
        "*.us",
        "*.uy",
        "*.uz",
        "*.va",
        "*.vacations",
        "*.vana",
        "*.vanguard",
        "*.vc",
        "*.ve",
        "*.vegas",
        "*.ventures",
        "*.verisign",
        "*.versicherung",
        "*.vet",
        "*.vg",
        "*.vi",
        "*.viajes",
        "*.video",
        "*.vig",
        "*.viking",
        "*.villas",
        "*.vin",
        "*.vip",
        "*.virgin",
        "*.visa",
        "*.vision",
        "*.vista",
        "*.vistaprint",
        "*.viva",
        "*.vivo",
        "*.vlaanderen",
        "*.vn",
        "*.vodka",
        "*.volkswagen",
        "*.volvo",
        "*.vote",
        "*.voting",
        "*.voto",
        "*.voyage",
        "*.vu",
        "*.vuelos",
        "*.wales",
        "*.walmart",
        "*.walter",
        "*.wang",
        "*.wanggou",
        "*.warman",
        "*.watch",
        "*.watches",
        "*.weather",
        "*.weatherchannel",
        "*.webcam",
        "*.weber",
        "*.website",
        "*.wed",
        "*.wedding",
        "*.weibo",
        "*.weir",
        "*.wf",
        "*.whoswho",
        "*.wien",
        "*.wiki",
        "*.williamhill",
        "*.win",
        "*.windows",
        "*.wine",
        "*.winners",
        "*.wme",
        "*.wolterskluwer",
        "*.woodside",
        "*.work",
        "*.works",
        "*.world",
        "*.wow",
        "*.ws",
        "*.wtc",
        "*.wtf",
        "*.xbox",
        "*.xerox",
        "*.xfinity",
        "*.xihuan",
        "*.xin",
        "*.xn--11b4c3d",
        "*.xn--1ck2e1b",
        "*.xn--1qqw23a",
        "*.xn--2scrj9c",
        "*.xn--30rr7y",
        "*.xn--3bst00m",
        "*.xn--3ds443g",
        "*.xn--3e0b707e",
        "*.xn--3hcrj9c",
        "*.xn--3oq18vl8pn36a",
        "*.xn--3pxu8k",
        "*.xn--42c2d9a",
        "*.xn--45br5cyl",
        "*.xn--45brj9c",
        "*.xn--45q11c",
        "*.xn--4gbrim",
        "*.xn--54b7fta0cc",
        "*.xn--55qw42g",
        "*.xn--55qx5d",
        "*.xn--5su34j936bgsg",
        "*.xn--5tzm5g",
        "*.xn--6frz82g",
        "*.xn--6qq986b3xl",
        "*.xn--80adxhks",
        "*.xn--80ao21a",
        "*.xn--80aqecdr1a",
        "*.xn--80asehdb",
        "*.xn--80aswg",
        "*.xn--8y0a063a",
        "*.xn--90a3ac",
        "*.xn--90ae",
        "*.xn--90ais",
        "*.xn--9dbq2a",
        "*.xn--9et52u",
        "*.xn--9krt00a",
        "*.xn--b4w605ferd",
        "*.xn--bck1b9a5dre4c",
        "*.xn--c1avg",
        "*.xn--c2br7g",
        "*.xn--cck2b3b",
        "*.xn--cg4bki",
        "*.xn--clchc0ea0b2g2a9gcd",
        "*.xn--czr694b",
        "*.xn--czrs0t",
        "*.xn--czru2d",
        "*.xn--d1acj3b",
        "*.xn--d1alf",
        "*.xn--e1a4c",
        "*.xn--eckvdtc9d",
        "*.xn--efvy88h",
        "*.xn--estv75g",
        "*.xn--fct429k",
        "*.xn--fhbei",
        "*.xn--fiq228c5hs",
        "*.xn--fiq64b",
        "*.xn--fiqs8s",
        "*.xn--fiqz9s",
        "*.xn--fjq720a",
        "*.xn--flw351e",
        "*.xn--fpcrj9c3d",
        "*.xn--fzc2c9e2c",
        "*.xn--fzys8d69uvgm",
        "*.xn--g2xx48c",
        "*.xn--gckr3f0f",
        "*.xn--gecrj9c",
        "*.xn--gk3at1e",
        "*.xn--h2breg3eve",
        "*.xn--h2brj9c",
        "*.xn--h2brj9c8c",
        "*.xn--hxt814e",
        "*.xn--i1b6b1a6a2e",
        "*.xn--imr513n",
        "*.xn--io0a7i",
        "*.xn--j1aef",
        "*.xn--j1amh",
        "*.xn--j6w193g",
        "*.xn--jlq61u9w7b",
        "*.xn--jvr189m",
        "*.xn--kcrx77d1x4a",
        "*.xn--kprw13d",
        "*.xn--kpry57d",
        "*.xn--kpu716f",
        "*.xn--kput3i",
        "*.xn--l1acc",
        "*.xn--lgbbat1ad8j",
        "*.xn--mgb9awbf",
        "*.xn--mgba3a3ejt",
        "*.xn--mgba3a4f16a",
        "*.xn--mgba7c0bbn0a",
        "*.xn--mgbaakc7dvf",
        "*.xn--mgbaam7a8h",
        "*.xn--mgbab2bd",
        "*.xn--mgbai9azgqp6j",
        "*.xn--mgbayh7gpa",
        "*.xn--mgbb9fbpob",
        "*.xn--mgbbh1a",
        "*.xn--mgbbh1a71e",
        "*.xn--mgbc0a9azcg",
        "*.xn--mgbca7dzdo",
        "*.xn--mgberp4a5d4ar",
        "*.xn--mgbgu82a",
        "*.xn--mgbi4ecexp",
        "*.xn--mgbpl2fh",
        "*.xn--mgbt3dhd",
        "*.xn--mgbtx2b",
        "*.xn--mgbx4cd0ab",
        "*.xn--mix891f",
        "*.xn--mk1bu44c",
        "*.xn--mxtq1m",
        "*.xn--ngbc5azd",
        "*.xn--ngbe9e0a",
        "*.xn--ngbrx",
        "*.xn--node",
        "*.xn--nqv7f",
        "*.xn--nqv7fs00ema",
        "*.xn--nyqy26a",
        "*.xn--o3cw4h",
        "*.xn--ogbpf8fl",
        "*.xn--otu796d",
        "*.xn--p1acf",
        "*.xn--p1ai",
        "*.xn--pbt977c",
        "*.xn--pgbs0dh",
        "*.xn--pssy2u",
        "*.xn--q9jyb4c",
        "*.xn--qcka1pmc",
        "*.xn--qxam",
        "*.xn--rhqv96g",
        "*.xn--rovu88b",
        "*.xn--rvc1e0am3e",
        "*.xn--s9brj9c",
        "*.xn--ses554g",
        "*.xn--t60b56a",
        "*.xn--tckwe",
        "*.xn--tiq49xqyj",
        "*.xn--unup4y",
        "*.xn--vermgensberater-ctb",
        "*.xn--vermgensberatung-pwb",
        "*.xn--vhquv",
        "*.xn--vuq861b",
        "*.xn--w4r85el8fhu5dnra",
        "*.xn--w4rs40l",
        "*.xn--wgbh1c",
        "*.xn--wgbl6a",
        "*.xn--xhq521b",
        "*.xn--xkc2al3hye2a",
        "*.xn--xkc2dl3a5ee0h",
        "*.xn--y9a3aq",
        "*.xn--yfro4i67o",
        "*.xn--ygbi2ammx",
        "*.xn--zfr164b",
        "*.xperia",
        "*.xxx",
        "*.xyz",
        "*.yachts",
        "*.yahoo",
        "*.yamaxun",
        "*.yandex",
        "*.ye",
        "*.yodobashi",
        "*.yoga",
        "*.yokohama",
        "*.you",
        "*.youtube",
        "*.yt",
        "*.yun",
        "*.za",
        "*.zappos",
        "*.zara",
        "*.zero",
        "*.zip",
        "*.zippo",
        "*.zm",
        "*.zone",
        "*.zuerich",
        "*.zw",
    ]
}
