// Draws the MixBar app icon at every size macOS asks for.
//
// Generated rather than hand-drawn so the geometry stays proportional at 16pt,
// where a scaled-down 1024 render turns to mush. Run: swift tools/make-icon.swift
import AppKit
import CoreGraphics
import Foundation

// Two jobs, one geometry:
//   swift tools/make-icon.swift [dir]   the .iconset the app bundle needs
//   swift tools/make-icon.swift --brand the committed README and link-preview art
let arguments = Array(CommandLine.arguments.dropFirst())
let brandMode = arguments.contains("--brand")
let outputDirectory = arguments.first { !$0.hasPrefix("--") } ?? "build/AppIcon.iconset"

/// One fader: how far along the track its knob sits, 0 at the bottom.
let faders: [CGFloat] = [0.30, 0.66, 0.46]

func makeContext(width: CGFloat, height: CGFloat) -> CGContext? {
    guard let context = CGContext(
        data: nil,
        width: Int(width), height: Int(height),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    return context
}

/// The mark, drawn to fill `canvas`. Every other asset composes this, so the
/// geometry has exactly one definition.
func drawMark(in canvas: CGRect, context: CGContext) {
    let space = CGColorSpaceCreateDeviceRGB()
    // macOS icons leave a transparent margin; the art sits on ~80% of the canvas.
    let inset = canvas.width * 0.098
    let plate = canvas.insetBy(dx: inset, dy: inset)

    drawPlate(plate, in: context, space: space)
    drawFaders(on: plate, in: context, size: canvas.width)
}

func draw(size: CGFloat) -> CGImage? {
    guard let context = makeContext(width: size, height: size) else { return nil }
    drawMark(in: CGRect(x: 0, y: 0, width: size, height: size), context: context)
    return context.makeImage()
}

/// The rounded gradient tile everything else sits on.
private func drawPlate(_ plate: CGRect, in context: CGContext, space: CGColorSpace) {
    // Apple's continuous-corner proportion.
    let radius = plate.width * 0.2237
    let squircle = CGPath(
        roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

    context.saveGState()
    defer { context.restoreGState() }
    context.addPath(squircle)
    context.clip()

    // Indigo to violet, lit from the top like the system icons.
    if let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.42, green: 0.36, blue: 0.95, alpha: 1),
            CGColor(red: 0.62, green: 0.24, blue: 0.89, alpha: 1),
        ] as CFArray,
        locations: [0, 1]) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: plate.midX, y: plate.maxY),
            end: CGPoint(x: plate.midX, y: plate.minY),
            options: [])
    }

    // A soft highlight across the top third, so the plate reads as glass.
    if let sheen = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0),
        ] as CFArray,
        locations: [0, 1]) {
        context.drawLinearGradient(
            sheen,
            start: CGPoint(x: plate.midX, y: plate.maxY),
            end: CGPoint(x: plate.midX, y: plate.midY),
            options: [])
    }
}

/// Three faders, the mark of a mixer.
private func drawFaders(on plate: CGRect, in context: CGContext, size: CGFloat) {
    let trackHeight = plate.height * 0.46
    let trackWidth = max(plate.width * 0.052, 1)
    let knobWidth = plate.width * 0.132
    let knobHeight = max(plate.height * 0.073, 2)
    let spacing = plate.width * 0.213

    for (index, position) in faders.enumerated() {
        let x = plate.midX + CGFloat(index - 1) * spacing
        let track = CGRect(
            x: x - trackWidth / 2, y: plate.midY - trackHeight / 2,
            width: trackWidth, height: trackHeight)
        context.addPath(CGPath(
            roundedRect: track, cornerWidth: trackWidth / 2,
            cornerHeight: trackWidth / 2, transform: nil))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.34))
        context.fillPath()

        let knobY = track.minY + track.height * position
        let knob = CGRect(
            x: x - knobWidth / 2, y: knobY - knobHeight / 2,
            width: knobWidth, height: knobHeight)
        drawKnob(knob, in: context, size: size)
    }
}

/// A knob, with just enough shadow to lift it off its track.
private func drawKnob(_ knob: CGRect, in context: CGContext, size: CGFloat) {
    context.saveGState()
    defer { context.restoreGState() }
    context.setShadow(
        offset: CGSize(width: 0, height: -size * 0.006),
        blur: size * 0.012,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.28))
    context.addPath(CGPath(
        roundedRect: knob, cornerWidth: knob.height / 2,
        cornerHeight: knob.height / 2, transform: nil))
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

// MARK: - Brand assets
//
// Committed to the repo (unlike the .icns, which is built), because the README
// and link previews have to render without anyone running a build first.

let brandWordmark = "MixBar"
let brandTagline = "Per-app volume for Mac"

/// A 1200x630 link-preview card: the mark, the wordmark, the tagline.
func drawSocialCard() -> CGImage? {
    let width: CGFloat = 1200, height: CGFloat = 630
    guard let context = makeContext(width: width, height: height) else { return nil }

    drawCardBackground(in: context, width: width, height: height)

    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    defer { NSGraphicsContext.current = previous }

    drawCardLockup(in: context, width: width, height: height)

    return context.makeImage()
}

/// Dark field with a violet bloom, so the gradient plate is the only bright
/// thing in the preview and the card does not read as flat black.
private func drawCardBackground(in context: CGContext, width: CGFloat, height: CGFloat) {
    context.setFillColor(CGColor(red: 0.047, green: 0.039, blue: 0.078, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 0.62, green: 0.24, blue: 0.89, alpha: 0.30),
            CGColor(red: 0.62, green: 0.24, blue: 0.89, alpha: 0),
        ] as CFArray,
        locations: [0, 1]) else { return }

    let centre = CGPoint(x: width * 0.30, y: height * 0.52)
    context.drawRadialGradient(
        glow, startCenter: centre, startRadius: 0,
        endCenter: centre, endRadius: width * 0.38, options: [])
}

/// Horizontal lockup: mark, gap, then the two lines of text, all centred as one
/// group so the card stays balanced whatever the tagline says.
private func drawCardLockup(in context: CGContext, width: CGFloat, height: CGFloat) {
    let wordmark = NSAttributedString(string: brandWordmark, attributes: [
        .font: NSFont.systemFont(ofSize: 92, weight: .semibold),
        .foregroundColor: NSColor.white,
        .kern: -2.0,
    ])
    let tagline = NSAttributedString(string: brandTagline, attributes: [
        .font: NSFont.systemFont(ofSize: 38, weight: .regular),
        .foregroundColor: NSColor(calibratedRed: 0.61, green: 0.59, blue: 0.68, alpha: 1),
    ])

    let markSize: CGFloat = 200
    let gap: CGFloat = 48
    let textWidth = max(wordmark.size().width, tagline.size().width)
    let originX = (width - (markSize + gap + textWidth)) / 2

    drawMark(
        in: CGRect(x: originX, y: (height - markSize) / 2, width: markSize, height: markSize),
        context: context)

    let textX = originX + markSize + gap
    let block = wordmark.size().height + tagline.size().height + 14
    let blockTop = (height + block) / 2
    wordmark.draw(at: CGPoint(x: textX, y: blockTop - wordmark.size().height))
    tagline.draw(at: CGPoint(x: textX, y: blockTop - block))
}

if brandMode {
    try? FileManager.default.createDirectory(
        atPath: "docs/brand", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(
        atPath: "site", withIntermediateDirectories: true)

    guard let mark = draw(size: 1024), let card = drawSocialCard() else {
        FileHandle.standardError.write(Data("brand asset rendering failed\n".utf8))
        exit(1)
    }
    write(mark, to: "docs/brand/mark-1024.png")
    write(card, to: "site/public/og.png")
    print("wrote docs/brand/mark-1024.png and site/public/og.png")
    exit(0)
}

try? FileManager.default.createDirectory(
    atPath: outputDirectory, withIntermediateDirectories: true)

// The exact set `iconutil` expects.
let variants: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    guard let image = draw(size: variant.pixels) else {
        FileHandle.standardError.write(Data("failed at \(variant.name)\n".utf8))
        exit(1)
    }
    write(image, to: "\(outputDirectory)/\(variant.name).png")
}
print("wrote \(variants.count) images to \(outputDirectory)")
