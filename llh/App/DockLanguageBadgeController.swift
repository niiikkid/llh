//
//  DockLanguageBadgeController.swift
//  llh
//

import AppKit

/// Composes the app Dock icon with an opaque circular flag badge at the top-trailing corner.
@MainActor
enum DockLanguageBadgeController {
    private static let fallbackTileSize = CGSize(width: 128, height: 128)
    private static let badgeDiameterScale: CGFloat = 0.46
    private static let badgeInsetScale: CGFloat = 0.04
    private static let minimumBadgeDiameter: CGFloat = 48

    static func update(for language: LearningLanguage?) {
        let tile = NSApp.dockTile
        tile.badgeLabel = nil

        guard let language, let flag = language.dockBadgeLabel else {
            tile.contentView = nil
            tile.display()
            return
        }

        let tileSize = tile.size.width > 0 ? tile.size : fallbackTileSize
        tile.contentView = makeCompositedTileView(flag: flag, tileSize: tileSize)
        tile.display()
    }

    private static func makeCompositedTileView(flag: String, tileSize: CGSize) -> NSView {
        let container = NSView(frame: NSRect(origin: .zero, size: tileSize))

        let iconView = NSImageView(frame: NSRect(origin: .zero, size: tileSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.autoresizingMask = [.width, .height]
        container.addSubview(iconView)

        let badgeDiameter = max(minimumBadgeDiameter, tileSize.width * badgeDiameterScale)
        let inset = max(3, tileSize.width * badgeInsetScale)
        // AppKit coordinates: origin bottom-left → top-trailing needs a high Y.
        let badgeFrame = NSRect(
            x: tileSize.width - badgeDiameter - inset,
            y: tileSize.height - badgeDiameter - inset,
            width: badgeDiameter,
            height: badgeDiameter
        )
        let badge = DockLanguageFlagBadgeView(frame: badgeFrame)
        badge.flag = flag
        container.addSubview(badge)

        return container
    }
}

/// Opaque gray circle with border and a large flag emoji (Dock badge style).
private final class DockLanguageFlagBadgeView: NSView {
    var flag: String = "" {
        didSet {
            flagLabel.stringValue = flag
            updateFlagFont()
        }
    }

    private let circleView = NSView()
    private let flagLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 2
        layer?.shadowOffset = CGSize(width: 0, height: -1)

        circleView.wantsLayer = true
        if let layer = circleView.layer {
            layer.backgroundColor = Self.badgeFillColor.cgColor
            layer.borderColor = Self.badgeBorderColor.cgColor
            layer.borderWidth = 1.5
            layer.masksToBounds = true
        }
        addSubview(circleView)

        flagLabel.isBezeled = false
        flagLabel.isEditable = false
        flagLabel.isSelectable = false
        flagLabel.drawsBackground = false
        flagLabel.backgroundColor = .clear
        flagLabel.alignment = .center
        flagLabel.lineBreakMode = .byClipping
        addSubview(flagLabel)

        updateFlagFont()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        circleView.frame = bounds
        circleView.layer?.cornerRadius = bounds.width / 2

        let labelInset = bounds.width * 0.06
        flagLabel.frame = bounds.insetBy(dx: labelInset, dy: labelInset)
        updateFlagFont()
    }

    private func updateFlagFont() {
        let fontSize = max(22, bounds.width * 0.64)
        flagLabel.font = .systemFont(ofSize: fontSize)
    }

    private static var badgeFillColor: NSColor {
        NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua:
                return NSColor(calibratedWhite: 0.36, alpha: 1)
            default:
                return NSColor(calibratedWhite: 0.94, alpha: 1)
            }
        }
    }

    private static var badgeBorderColor: NSColor {
        NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua:
                return NSColor(calibratedWhite: 0.62, alpha: 1)
            default:
                return NSColor(calibratedWhite: 0.55, alpha: 1)
            }
        }
    }
}
