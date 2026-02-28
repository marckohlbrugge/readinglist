import AppKit

enum AppIconFactory {
    static func makeAppIcon(size: CGFloat = 512) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        defer { image.unlockFocus() }

        let canvas = NSRect(origin: .zero, size: imageSize)
        NSColor.clear.setFill()
        canvas.fill()

        // Inset the artwork a bit so the icon doesn't appear optically larger than others.
        let iconRect = canvas.insetBy(dx: size * 0.065, dy: size * 0.065)
        let cornerRadius = iconRect.width * 0.225
        let roundedBackground = NSBezierPath(
            roundedRect: iconRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        NSColor.white.setFill()
        roundedBackground.fill()

        drawSymbol(in: iconRect)

        return image
    }

    private static func drawSymbol(in canvas: NSRect) {
        guard let symbol = NSImage(systemSymbolName: "eyeglasses", accessibilityDescription: nil) else {
            return
        }

        let iconSide = min(canvas.width, canvas.height)
        let config = NSImage.SymbolConfiguration(
            pointSize: iconSide * 0.44,
            weight: .regular
        )
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: NSColor.black)
        let mergedConfig = config.applying(colorConfig)
        let tinted = symbol.withSymbolConfiguration(mergedConfig) ?? symbol

        let maxRect = canvas.insetBy(dx: iconSide * 0.19, dy: iconSide * 0.27)
        let symbolRect = aspectFitRect(
            for: tinted.size,
            in: maxRect
        )
        tinted.draw(
            in: symbolRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
    }

    private static func aspectFitRect(for sourceSize: NSSize, in destination: NSRect) -> NSRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return destination
        }

        let widthScale = destination.width / sourceSize.width
        let heightScale = destination.height / sourceSize.height
        let scale = min(widthScale, heightScale)

        let fittedSize = NSSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )

        return NSRect(
            x: destination.midX - fittedSize.width / 2,
            y: destination.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
