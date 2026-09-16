import AppKit
import Foundation

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let s = CGFloat(pixels) / 1024
        let transform = NSAffineTransform()
        transform.scale(by: s)
        transform.concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 220, yRadius: 220)
        NSColor(calibratedRed: 0.965, green: 0.965, blue: 0.973, alpha: 1).setFill(); background.fill()
        NSColor(calibratedRed: 0.0, green: 0.4, blue: 0.8, alpha: 1).setStroke()
        for radius: CGFloat in [210, 350] {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: 512, y: 315), radius: radius, startAngle: 40, endAngle: 140)
            arc.lineWidth = 53; arc.lineCapStyle = .round; arc.stroke()
        }
        NSColor(calibratedRed: 0.0, green: 0.4, blue: 0.8, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 472, y: 275, width: 80, height: 80)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size)\(suffix).png"))
    }
}
