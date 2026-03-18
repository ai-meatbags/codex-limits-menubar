import Cocoa

struct MenuPreviewFactory {
    private static let previewWidth: CGFloat = 340

    static func usageBarsItem(snapshot: MenubarSnapshot) -> NSMenuItem? {
        guard let previewView = usageBarsPreviewView(snapshot: snapshot) else {
            return nil
        }

        let item = NSMenuItem()
        item.view = previewView
        return item
    }

    static func usageBarsPreviewView(snapshot: MenubarSnapshot) -> NSView? {
        guard !snapshot.buckets.isEmpty else {
            return nil
        }

        return usageBarsView(snapshot: snapshot)
    }

    private static func usageBarsView(snapshot: MenubarSnapshot) -> NSView {
        let appearance = NSApp.effectiveAppearance
        let root = verticalStack(spacing: 8)
        root.appearance = appearance
        root.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        root.wantsLayer = true
        root.layer?.cornerRadius = 10
        root.layer?.backgroundColor = cardBackgroundColor(for: appearance)
            .withAlphaComponent(0.96)
            .cgColor

        for bucket in topBuckets(snapshot) {
            let block = verticalStack(spacing: 3)
            block.appearance = appearance

            let header = NSStackView()
            header.appearance = appearance
            header.orientation = .horizontal
            header.alignment = .centerY
            header.distribution = .fill
            header.spacing = 6
            header.addArrangedSubview(titleLabel(bucket.windowLabel, font: .systemFont(ofSize: 11, weight: .semibold)))
            header.addArrangedSubview(NSView())
            header.addArrangedSubview(trailingLabel("\(bucket.remainingPercent)%", font: .systemFont(ofSize: 11, weight: .semibold)))

            let progress = NSProgressIndicator()
            progress.isIndeterminate = false
            progress.minValue = 0
            progress.maxValue = 100
            progress.doubleValue = Double(bucket.remainingPercent)
            progress.controlSize = .small
            progress.sizeToFit()

            block.addArrangedSubview(header)
            block.addArrangedSubview(progress)
            block.addArrangedSubview(footnoteLabel("Resets \(bucket.resetLabel)"))
            root.addArrangedSubview(block)
        }

        root.frame = NSRect(x: 0, y: 0, width: previewWidth, height: root.fittingSize.height)
        return root
    }

    private static func topBuckets(_ snapshot: MenubarSnapshot) -> [SnapshotBucket] {
        Array(snapshot.buckets.prefix(2))
    }

    private static func verticalStack(spacing: CGFloat) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private static func titleLabel(_ string: String, font: NSFont) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = font
        label.textColor = primaryTextColor(for: NSApp.effectiveAppearance)
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private static func footnoteLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: 10)
        label.textColor = secondaryTextColor(for: NSApp.effectiveAppearance)
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private static func trailingLabel(_ string: String, font: NSFont) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = font
        label.textColor = primaryTextColor(for: NSApp.effectiveAppearance)
        label.alignment = .right
        return label
    }

    private static func cardBackgroundColor(for appearance: NSAppearance) -> NSColor {
        isDarkMode(appearance)
            ? NSColor(calibratedWhite: 0.16, alpha: 1)
            : NSColor(calibratedWhite: 0.97, alpha: 1)
    }

    private static func primaryTextColor(for appearance: NSAppearance) -> NSColor {
        isDarkMode(appearance)
            ? NSColor(calibratedWhite: 0.95, alpha: 1)
            : NSColor(calibratedWhite: 0.12, alpha: 1)
    }

    private static func secondaryTextColor(for appearance: NSAppearance) -> NSColor {
        isDarkMode(appearance)
            ? NSColor(calibratedWhite: 0.72, alpha: 1)
            : NSColor(calibratedWhite: 0.42, alpha: 1)
    }

    private static func isDarkMode(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
