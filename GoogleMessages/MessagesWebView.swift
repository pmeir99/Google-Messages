import SwiftUI
import WebKit
import Network

enum MessagesSection: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case archived = "Archived"
    case spam = "Spam & blocked"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .inbox: return "bubble.left.and.bubble.right.fill"
        case .archived: return "archivebox"
        case .spam: return "hand.raised"
        case .settings: return "gearshape"
        }
    }
}

struct MessagesWebView: UIViewRepresentable {
    let section: MessagesSection
    let zoom: Double
    @ObservedObject var connectivity: ConnectivityMonitor

    func makeCoordinator() -> Coordinator {
        Coordinator(connectivity: connectivity)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isDirectionalLockEnabled = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.pageZoom = zoom
        context.coordinator.webView = webView
        context.coordinator.lastSection = section
        webView.load(URLRequest(url: Self.homeURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.pageZoom = zoom
        context.coordinator.connectivity = connectivity
        guard context.coordinator.lastSection != section else { return }
        context.coordinator.lastSection = section

        if section == .inbox {
            webView.load(URLRequest(url: Self.homeURL))
        } else {
            context.coordinator.openSection(section)
        }
    }

    private static let homeURL = URL(string: "https://messages.google.com/web/")!

    final class Coordinator: NSObject, WKNavigationDelegate, ObservableObject {
        weak var webView: WKWebView?
        var lastSection: MessagesSection
        var connectivity: ConnectivityMonitor
        private var reloadObserver: NSObjectProtocol?

        init(connectivity: ConnectivityMonitor) {
            self.connectivity = connectivity
            self.lastSection = .inbox
            super.init()
            self.reloadObserver = NotificationCenter.default.addObserver(
                forName: .messagesReloadRequested, object: nil, queue: .main
            ) { [weak self] _ in
                self?.webView?.reload()
            }
        }

        deinit {
            if let reloadObserver {
                NotificationCenter.default.removeObserver(reloadObserver)
            }
        }

        func openSection(_ section: MessagesSection) {
            let label: String
            switch section {
            case .inbox: return
            case .archived: label = "Archived"
            case .spam: label = "Spam & blocked"
            case .settings: label = "Settings"
            }

            // Use Google's visible menu controls so route changes stay compatible
            // with the account index and URL structure chosen by Google.
            let script = """
            (() => {
              const find = (text) => [...document.querySelectorAll('button,[role="button"],a')]
                .find(el => (el.getAttribute('aria-label') || el.innerText || '').trim() === text);
              const menu = find('Main menu');
              if (menu && menu.getAttribute('aria-expanded') !== 'true') menu.click();
              setTimeout(() => { const item = find(\(Self.jsString(label))); if (item) item.click(); }, 120);
            })();
            """
            webView?.evaluateJavaScript(script)
        }

        private static func jsString(_ value: String) -> String {
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            return "'\(escaped)'"
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            NotificationCenter.default.post(name: .messagesWebViewLoaded, object: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            NotificationCenter.default.post(name: .messagesWebViewFailed, object: error.localizedDescription)
        }
    }
}

extension Notification.Name {
    static let messagesWebViewLoaded = Notification.Name("messagesWebViewLoaded")
    static let messagesWebViewFailed = Notification.Name("messagesWebViewFailed")
}

final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "GoogleMessages.network-monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.isOnline = path.status == .satisfied }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
