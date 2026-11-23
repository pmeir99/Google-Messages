import SwiftUI
import WebKit
import Network

@MainActor
final class MessagesWebEngine: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    @Published private(set) var conversations: [MessageConversation] = []
    @Published private(set) var messages: [MessageItem] = []
    @Published private(set) var connected = false
    @Published private(set) var activeTitle = ""
    @Published private(set) var pageStatus = "Loading Google Messages…"
    let webView: WKWebView
    private var reloadObserver: NSObjectProtocol?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        config.allowsInlineMediaPlayback = true
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.bridgeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController = controller
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        controller.add(self, name: "messagesBridge")
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isDirectionalLockEnabled = true
        reloadObserver = NotificationCenter.default.addObserver(forName: .messagesReloadRequested, object: nil, queue: .main) { [weak self] _ in
            self?.webView.reload()
        }
        webView.load(URLRequest(url: URL(string: "https://messages.google.com/web/")!))
    }

    deinit {
        if let reloadObserver { NotificationCenter.default.removeObserver(reloadObserver) }
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "messagesBridge")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "messagesBridge",
              let data = try? JSONSerialization.data(withJSONObject: message.body),
              let snapshot = try? JSONDecoder().decode(MessagesSnapshot.self, from: data) else { return }
        conversations = snapshot.conversations
        messages = snapshot.messages
        activeTitle = snapshot.activeTitle
        connected = snapshot.connected
        pageStatus = snapshot.status
        NotificationCenter.default.post(name: .messagesBridgeUpdated, object: snapshot)
    }

    func selectConversation(_ conversation: MessageConversation) {
        webView.evaluateJavaScript("window.__gmNative.selectConversation(\(Self.js(conversation.title)))")
    }
    func send(_ text: String) { webView.evaluateJavaScript("window.__gmNative.send(\(Self.js(text)))") }
    func startNewConversation() { webView.evaluateJavaScript("window.__gmNative.newConversation()") }
    func openAttachmentPicker() { webView.evaluateJavaScript("window.__gmNative.attach()") }
    func sendAttachment(_ data: Data, mime: String, name: String) {
        let encoded = data.base64EncodedString()
        let script = """
        (() => {
          const input = document.querySelector('input[type="file"]');
          if (!input) return;
          const bytes = Uint8Array.from(atob('\(encoded)'), c => c.charCodeAt(0));
          const file = new File([bytes], \(Self.js(name)), {type: \(Self.js(mime))});
          const transfer = new DataTransfer();
          transfer.items.add(file);
          input.files = transfer.files;
          input.dispatchEvent(new Event('change', {bubbles:true}));
        })();
        """
        webView.evaluateJavaScript(script)
    }
    func openGoogleSettings() { webView.evaluateJavaScript("window.__gmNative.settings()") }

    private static func js(_ value: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [value], options: [.fragmentsAllowed])
        return String(data: data, encoding: .utf8)!.dropFirst().dropLast().description
    }

    private static let bridgeScript = #"""
    (() => {
      if (window.__gmNative) return;
      const norm = s => (s || '').replace(/\s+/g, ' ').trim();
      const label = e => norm(e.getAttribute('aria-label') || e.innerText || e.textContent);
      const post = () => {
        const list = [...document.querySelectorAll('[role="listbox"] [role="option"], [role="listbox"] [role="listitem"]')];
        const conversations = list.map((e, i) => {
          const bits = [...e.querySelectorAll('h1,h2,h3,[role="heading"],time,[aria-label]')].map(label).filter(Boolean);
          const text = norm(e.innerText);
          const title = bits.find(x => x.length < 80) || text.split('\n')[0] || 'Conversation';
          const time = e.querySelector('time')?.innerText || '';
          return {id: e.getAttribute('data-id') || title + '-' + i, title, preview: text.replace(title, '').trim(), time,
            unread: /unread/i.test(e.getAttribute('aria-label') || '') || !!e.querySelector('[aria-label*="unread" i]'),
            group: !!e.querySelector('[aria-label*="group" i]')};
        });
        const active = document.querySelector('[role="main"]');
        const title = norm(active?.querySelector('h1,[role="heading"]')?.innerText || '');
        const items = [...(active || document).querySelectorAll('[role="listitem"],[data-message-id]')].filter(e => !e.closest('[role="listbox"]'));
        const messages = items.map((e, i) => {
          const text = norm(e.innerText || e.textContent);
          const attachment = e.querySelector('img,video,audio,[role="img"]');
          return {id:e.getAttribute('data-message-id') || 'm-' + i + '-' + text.slice(0,18), text,
            time:e.querySelector('time')?.innerText || '',
            outgoing:/outgoing|sent|you:/i.test(e.getAttribute('class') + ' ' + (e.getAttribute('aria-label') || '')),
            status:/read|delivered|sent/i.test(e.getAttribute('aria-label') || '') ? (e.getAttribute('aria-label') || '') : '',
            attachment:attachment ? label(attachment) || 'Attachment' : null};
        }).filter(x => x.text || x.attachment);
        const connected = conversations.length > 0;
        const result = {connected, conversations, messages, activeTitle:title, status:connected ? 'Connected to Google Messages' : 'Sign in or pair your phone'};
        const key = JSON.stringify(result);
        if (key !== window.__gmNative.last) { window.__gmNative.last = key; window.webkit.messageHandlers.messagesBridge.postMessage(result); }
      };
      const findText = (selectors, text) => [...document.querySelectorAll(selectors)].find(e => label(e) === text || label(e).includes(text));
      window.__gmNative = {
        last:'',
        selectConversation: title => { const e = [...document.querySelectorAll('[role="option"],[role="listitem"]')].find(x => label(x).includes(title)); e?.click(); },
        send: text => {
          const box = [...document.querySelectorAll('[contenteditable="true"],textarea,[role="textbox"]')].filter(e => e.getClientRects().length).pop();
          if (!box) return;
          box.focus();
          if (box.tagName === 'TEXTAREA') { const setter=Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set; setter.call(box,text); }
          else { box.textContent=text; }
          box.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:text}));
          const btn = findText('button,[role="button"]','Send') || box.closest('form')?.querySelector('button[type="submit"]');
          btn?.click();
        },
        newConversation: () => (findText('button,[role="button"]','New conversation') || findText('button,[role="button"]','Start chat'))?.click(),
        attach: () => document.querySelector('input[type="file"]')?.click(),
        settings: () => (findText('a,button,[role="button"]','Settings') || findText('a,button,[role="button"]','Main menu'))?.click()
      };
      new MutationObserver(post).observe(document.documentElement,{childList:true,subtree:true,characterData:true,attributes:true});
      post(); setInterval(post,1800);
    })();
    """#
}

struct MessagesWebHost: UIViewRepresentable {
    @ObservedObject var engine: MessagesWebEngine
    var visible: Bool
    func makeUIView(context: Context) -> WKWebView { engine.webView }
    func updateUIView(_ view: WKWebView, context: Context) {
        view.isHidden = false
        view.alpha = 1
        view.scrollView.isScrollEnabled = visible
        view.isUserInteractionEnabled = visible
    }
}

final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "GoogleMessages.network-monitor")
    init() {
        monitor.pathUpdateHandler = { [weak self] path in DispatchQueue.main.async { self?.isOnline = path.status == .satisfied } }
        monitor.start(queue: queue)
    }
    deinit { monitor.cancel() }
}

extension Notification.Name {
    static let messagesReloadRequested = Notification.Name("messagesReloadRequested")
    static let messagesWebViewLoaded = Notification.Name("messagesWebViewLoaded")
    static let messagesWebViewFailed = Notification.Name("messagesWebViewFailed")
    static let messagesBridgeUpdated = Notification.Name("messagesBridgeUpdated")
}
