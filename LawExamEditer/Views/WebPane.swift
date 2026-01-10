import SwiftUI
import WebKit

struct WebPane: View {
    @EnvironmentObject private var caseStore: CaseStore
    @State private var loadTrigger = UUID()
    @State private var errorMessage: String?
    @State private var lastURLString = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Reload") {
                    loadTrigger = UUID()
                }
                Button("Open in Browser") {
                    openInBrowser()
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            WebViewContainer(urlString: currentURLString, loadTrigger: loadTrigger, errorMessage: $errorMessage)
                .background(Color(NSColor.textBackgroundColor))
                .overlay {
                    if let message = placeholderMessage {
                        VStack(spacing: 8) {
                            Text(message)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            if errorMessage != nil {
                                Button("Retry") {
                                    loadTrigger = UUID()
                                }
                            }
                        }
                        .padding()
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goodnotesLoadRequested)) { _ in
            loadTrigger = UUID()
        }
        .onChange(of: currentURLString) { newValue in
            if newValue != lastURLString {
                lastURLString = newValue
                loadTrigger = UUID()
            }
        }
    }

    private var currentURLString: String {
        caseStore.cases.first(where: { $0.id == caseStore.selectedCaseID })?.meta.goodnotesURL ?? ""
    }

    private var placeholderMessage: String? {
        if currentURLString.isEmpty {
            return "URL not set"
        }
        return errorMessage
    }

    private func openInBrowser() {
        guard let url = URL(string: currentURLString), !currentURLString.isEmpty else {
            errorMessage = "Invalid URL"
            return
        }
        NSWorkspace.shared.open(url)
    }
}

struct WebViewContainer: NSViewRepresentable {
    let urlString: String
    let loadTrigger: UUID
    @Binding var errorMessage: String?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastTrigger == loadTrigger {
            return
        }
        context.coordinator.lastTrigger = loadTrigger
        guard !urlString.isEmpty else {
            errorMessage = "URL not set"
            return
        }
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        errorMessage = nil
        webView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(errorMessage: $errorMessage)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var errorMessage: String?
        var lastTrigger = UUID()

        init(errorMessage: Binding<String?>) {
            _errorMessage = errorMessage
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
    }
}
