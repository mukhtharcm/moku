#!/usr/bin/swift

import AppKit
import Foundation

let arguments = CommandLine.arguments

guard arguments.count == 2 else {
    fputs("Usage: generate-dmg-background.swift <output-png-path>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let canvasSize = CGSize(width: 1280, height: 720)
let rect = CGRect(origin: .zero, size: canvasSize)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create bitmap context.\n", stderr)
    exit(1)
}

bitmap.size = canvasSize

guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create graphics context.\n", stderr)
    exit(1)
}

let context = graphicsContext.cgContext

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedRed: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
}

// Warm cream gradient background (matching Moku's bookish theme)
func drawBackground() {
    let gradient = NSGradient(colors: [
        color(250, 247, 242),  // warm cream #FAF7F2
        color(245, 240, 230)   // slightly deeper warm
    ]) ?? NSGradient(starting: color(250, 247, 242), ending: color(245, 240, 230))!
    gradient.draw(in: NSBezierPath(rect: rect), angle: -12)
}

func drawGlow(center: CGPoint, radius: CGFloat, glowColor: NSColor) {
    context.saveGState()

    let colors = [glowColor.withAlphaComponent(0.20).cgColor, glowColor.withAlphaComponent(0.0).cgColor] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    guard
        let rgb = CGColorSpace(name: CGColorSpace.sRGB),
        let gradient = CGGradient(colorsSpace: rgb, colors: colors, locations: locations)
    else {
        context.restoreGState()
        return
    }

    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    context.restoreGState()
}

// Draw a subtle bookmark shape in the center
func drawBookmark(center: CGPoint, width: CGFloat, height: CGFloat) {
    context.saveGState()

    let left = center.x - width / 2
    let right = center.x + width / 2
    let top = center.y + height / 2
    let bottom = center.y - height / 2
    let notchDepth = height * 0.15

    let path = NSBezierPath()
    path.move(to: CGPoint(x: left, y: top))
    path.line(to: CGPoint(x: right, y: top))
    path.line(to: CGPoint(x: right, y: bottom))
    path.line(to: CGPoint(x: center.x, y: bottom + notchDepth))
    path.line(to: CGPoint(x: left, y: bottom))
    path.close()

    // Coral fill with low opacity
    color(255, 138, 101, 0.08).setFill()
    path.fill()

    // Coral stroke
    path.lineWidth = 2
    color(255, 138, 101, 0.15).setStroke()
    path.stroke()

    context.restoreGState()
}

func drawInsetFrame() {
    let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 24, dy: 24), xRadius: 24, yRadius: 24)
    frame.lineWidth = 2
    color(255, 255, 255, 0.6).setStroke()
    frame.stroke()
}

// Draw the background
drawBackground()

// Violet glow on the left
drawGlow(center: CGPoint(x: 300, y: 360), radius: 280, glowColor: color(107, 78, 255))  // #6B4EFF

// Coral glow on the right
drawGlow(center: CGPoint(x: 980, y: 360), radius: 250, glowColor: color(255, 138, 101))  // #FF8A65

// Subtle bookmark watermark in center
drawBookmark(center: CGPoint(x: 640, y: 380), width: 120, height: 180)

// Inset frame
drawInsetFrame()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode DMG background image.\n", stderr)
    exit(1)
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: nil
    )
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("Failed to write DMG background image: \(error)\n", stderr)
    exit(1)
}
