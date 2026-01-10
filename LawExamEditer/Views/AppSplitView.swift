import SwiftUI

struct AppSplitView: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> AppSplitViewController {
        AppSplitViewController()
    }

    func updateNSViewController(_ nsViewController: AppSplitViewController, context: Context) {
        nsViewController.refreshLayoutsIfNeeded()
    }
}

final class AppSplitViewController: NSViewController, NSSplitViewDelegate {
    private let horizontalSplit = NSSplitView()
    private let rightSplit = NSSplitView()

    private let leftHost = NSHostingView(rootView: EditorPane())
    private let topRightHost = NSHostingView(rootView: CaseOrganizerPane())
    private let bottomRightHost = NSHostingView(rootView: WebPane())

    private var didRestoreSplit = false

    private let horizontalKey = "split.horizontal"
    private let verticalKey = "split.vertical"

    override func loadView() {
        view = NSView()
        setupSplitViews()
    }

    func refreshLayoutsIfNeeded() {
        if !didRestoreSplit {
            restoreSplitPositions()
        }
    }

    private func setupSplitViews() {
        horizontalSplit.isVertical = true
        horizontalSplit.delegate = self
        horizontalSplit.dividerStyle = .thin
        horizontalSplit.translatesAutoresizingMaskIntoConstraints = false

        rightSplit.isVertical = false
        rightSplit.delegate = self
        rightSplit.dividerStyle = .thin
        rightSplit.translatesAutoresizingMaskIntoConstraints = false

        horizontalSplit.addArrangedSubview(leftHost)
        horizontalSplit.addArrangedSubview(rightSplit)

        rightSplit.addArrangedSubview(topRightHost)
        rightSplit.addArrangedSubview(bottomRightHost)

        view.addSubview(horizontalSplit)

        NSLayoutConstraint.activate([
            horizontalSplit.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            horizontalSplit.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            horizontalSplit.topAnchor.constraint(equalTo: view.topAnchor),
            horizontalSplit.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func restoreSplitPositions() {
        didRestoreSplit = true
        let defaults = UserDefaults.standard
        let horizontal = defaults.double(forKey: horizontalKey)
        let vertical = defaults.double(forKey: verticalKey)

        let horizontalPosition = horizontal > 0 ? horizontal : view.bounds.width * 0.5
        let verticalPosition = vertical > 0 ? vertical : view.bounds.height * 0.33

        horizontalSplit.setPosition(horizontalPosition, ofDividerAt: 0)
        rightSplit.setPosition(verticalPosition, ofDividerAt: 0)
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        let defaults = UserDefaults.standard
        if notification.object as? NSSplitView === horizontalSplit {
            let position = horizontalSplit.subviews.first?.frame.width ?? 0
            defaults.set(position, forKey: horizontalKey)
        } else if notification.object as? NSSplitView === rightSplit {
            let position = rightSplit.subviews.first?.frame.height ?? 0
            defaults.set(position, forKey: verticalKey)
        }
    }
}

