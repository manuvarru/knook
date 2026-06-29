import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render-app-icon.swift <output.png>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Unable to create drawing context.\n", stderr)
    exit(1)
}

// 1. Transparent background
context.clear(CGRect(x: 0, y: 0, width: size, height: size))

// 2. Draw a perfect macOS squircle shape (width/height 824 in a 1024 canvas is the Apple standard grid)
let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 180, cornerHeight: 180, transform: nil)
context.setFillColor(NSColor.white.cgColor)
context.addPath(squirclePath)
context.fillPath()

// 3. Draw the black pause bars inside the squircle
context.setFillColor(NSColor.black.cgColor)
let barWidth: CGFloat = 110
let barHeight: CGFloat = 380
let barRadius: CGFloat = 35
let barGap: CGFloat = 85
let totalWidth = (barWidth * 2) + barGap
let firstX = (CGFloat(size) - totalWidth) / 2
let y = (CGFloat(size) - barHeight) / 2

for x in [firstX, firstX + barWidth + barGap] {
    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
    let path = CGPath(roundedRect: rect, cornerWidth: barRadius, cornerHeight: barRadius, transform: nil)
    context.addPath(path)
    context.fillPath()
}

guard let image = context.makeImage() else {
    fputs("Unable to create icon image.\n", stderr)
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: image)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode PNG.\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("Unable to write icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
