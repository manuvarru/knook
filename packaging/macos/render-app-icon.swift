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
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fputs("Unable to create drawing context.\n", stderr)
    exit(1)
}

let canvas = CGRect(x: 0, y: 0, width: size, height: size)
context.setFillColor(NSColor.white.cgColor)
context.fill(canvas)

context.setFillColor(NSColor.black.cgColor)
let barWidth: CGFloat = 128
let barHeight: CGFloat = 440
let barRadius: CGFloat = 38
let barGap: CGFloat = 96
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
