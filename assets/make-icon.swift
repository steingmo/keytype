// Renders the KeyType app icon as a 1024x1024 PNG.
// Run: swift assets/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background squircle — macOS icon grid: 824pt tile on a 1024 canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(
    starting: NSColor(red: 0.16, green: 0.13, blue: 0.11, alpha: 1),
    ending: NSColor(red: 0.07, green: 0.055, blue: 0.05, alpha: 1)
)!.draw(in: squircle, angle: -90)

// Faint top edge highlight on the tile.
squircle.setClip()
NSColor.white.withAlphaComponent(0.06).setStroke()
let edge = NSBezierPath(roundedRect: tile.insetBy(dx: 3, dy: 3), xRadius: 182, yRadius: 182)
edge.lineWidth = 6
edge.stroke()

// Keycap: darker "side" below, gradient top face above.
let capSide = NSRect(x: 292, y: 262, width: 440, height: 440)
let capTop = NSRect(x: 292, y: 306, width: 440, height: 440)

NSColor(red: 0.13, green: 0.20, blue: 0.52, alpha: 1).setFill()
NSBezierPath(roundedRect: capSide, xRadius: 92, yRadius: 92).fill()

let topPath = NSBezierPath(roundedRect: capTop, xRadius: 92, yRadius: 92)
NSGradient(
    starting: NSColor(red: 0.42, green: 0.56, blue: 1.00, alpha: 1),
    ending: NSColor(red: 0.22, green: 0.38, blue: 0.92, alpha: 1)
)!.draw(in: topPath, angle: -90)

// Subtle highlight along the keycap's top edge.
NSGraphicsContext.current?.saveGraphicsState()
topPath.setClip()
NSColor.white.withAlphaComponent(0.35).setStroke()
let capHighlight = NSBezierPath(roundedRect: capTop.insetBy(dx: 4, dy: 4), xRadius: 88, yRadius: 88)
capHighlight.lineWidth = 8
capHighlight.stroke()
NSGraphicsContext.current?.restoreGraphicsState()

// "⌘V" legend on the keycap.
let legend = "⌘V" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 190, weight: .semibold),
    .foregroundColor: NSColor.white,
]
let textSize = legend.size(withAttributes: attributes)
legend.draw(
    at: NSPoint(x: capTop.midX - textSize.width / 2, y: capTop.midY - textSize.height / 2),
    withAttributes: attributes
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon\n", stderr)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
