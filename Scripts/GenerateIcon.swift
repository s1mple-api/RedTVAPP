import AppKit
import CoreGraphics
import ImageIO

// One editable vector geometry supplies the icon, in-app logo and launch assets.
// Run from the project root: swift Scripts/GenerateIcon.swift
enum AssetError: Error { case bitmapContext, image, pdfContext }
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("RedTV/Resources/Assets.xcassets")
let branding = root.appendingPathComponent("Branding")
try FileManager.default.createDirectory(at: branding, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let red = color(0xFF2442), ivory = color(0xFFFFFF)
let darkPaper = color(0x101216), darkInk = color(0xFFFFFF)

// A bold R forms the brand silhouette. Its counter is a television window,
// containing the original public Valve operator outline as a secondary detail.
let operatorSource = try String(contentsOf: branding.appendingPathComponent("Source/CSOperator.svg"), encoding: .utf8)
let pathRegex = try NSRegularExpression(pattern: "d=\"([^\"]+)\"")
let match = pathRegex.firstMatch(in: operatorSource, range: NSRange(operatorSource.startIndex..., in: operatorSource))!
let operatorData = String(operatorSource[Range(match.range(at: 1), in: operatorSource)!])

func svgPath(_ source: String) throws -> CGPath {
    let regex = try NSRegularExpression(pattern: "[MLHVCZ]|-?[0-9]*\\.?[0-9]+(?:[eE][-+]?[0-9]+)?")
    let tokens = regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).map { String(source[Range($0.range, in: source)!]) }
    let path = CGMutablePath()
    var index = 0, command = "M"
    func number() -> CGFloat { defer { index += 1 }; return CGFloat(Double(tokens[index])!) }
    while index < tokens.count {
        if tokens[index].count == 1, "MLHVCZ".contains(tokens[index]) {
            command = tokens[index]; index += 1
            if command == "Z" { path.closeSubpath(); continue }
        }
        switch command {
        case "M": path.move(to: CGPoint(x: number(), y: number())); command = "L"
        case "L": path.addLine(to: CGPoint(x: number(), y: number()))
        case "H": path.addLine(to: CGPoint(x: number(), y: path.currentPoint.y))
        case "V": path.addLine(to: CGPoint(x: path.currentPoint.x, y: number()))
        case "C":
            let first = CGPoint(x: number(), y: number()), second = CGPoint(x: number(), y: number()), end = CGPoint(x: number(), y: number())
            path.addCurve(to: end, control1: first, control2: second)
        default: fatalError("Unsupported SVG path command: \(command)")
        }
    }
    return path
}
let operatorPath = try svgPath(operatorData)
let rData = "M216 192V832H604C738 832 804 760 804 650C804 550 766 500 682 476L834 192H666L529 454H370V192Z"
let rPath = try svgPath(rData)
let window = CGRect(x: 370, y: 558, width: 288, height: 214)
let operatorHeight: CGFloat = 186
let operatorBottom: CGFloat = 572
let operatorCenterX: CGFloat = 514

func drawMark(_ context: CGContext, ink: CGColor) {
    context.saveGState()
    // Slight optical enlargement gives the monogram the same visual weight as
    // an iOS home-screen icon, while preserving a generous red safe area.
    context.translateBy(x: 512, y: 512)
    context.scaleBy(x: 1.12, y: 1.12)
    context.translateBy(x: -525, y: -512)
    context.setFillColor(ink)
    context.addPath(rPath)
    context.addPath(CGPath(roundedRect: window, cornerWidth: 32, cornerHeight: 32, transform: nil))
    context.drawPath(using: .eoFill)
    let bounds = operatorPath.boundingBoxOfPath
    let scale = operatorHeight / bounds.height
    let width = bounds.width * scale
    context.translateBy(x: operatorCenterX - width / 2, y: operatorBottom + operatorHeight)
    context.scaleBy(x: scale, y: -scale)
    context.translateBy(x: -bounds.minX, y: -bounds.minY)
    context.addPath(operatorPath)
    context.fillPath()
    context.restoreGState()
}

func writePNG(_ url: URL, width: Int, height: Int, draw: (CGContext) -> Void) throws {
    // An opaque Core Graphics surface avoids unsupported 24-bit AppKit drawing.
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw AssetError.bitmapContext }
    draw(context)
    guard let image = context.makeImage(), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw AssetError.image }
    try png.write(to: url)
}

func writePDF(_ url: URL, bounds: CGRect, draw: (CGContext) -> Void) throws {
    var mediaBox = bounds
    guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw AssetError.pdfContext }
    context.beginPDFPage(nil)
    draw(context)
    context.endPDFPage()
    context.closePDF()
}

for dark in [false, true] {
    let name = dark ? "AppIcon-dark.png" : "AppIcon.png"
    try writePNG(assets.appendingPathComponent("AppIcon.appiconset/\(name)"), width: 1024, height: 1024) { context in
        context.setFillColor(red)
        context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        drawMark(context, ink: ivory)
    }
    let suffix = dark ? "-dark" : ""
    try writePDF(assets.appendingPathComponent("BrandMark.imageset/BrandMark\(suffix).pdf"), bounds: CGRect(x: 0, y: 0, width: 736, height: 760)) { context in
        // Asset catalogs expect a zero-origin PDF page; translate the artwork,
        // rather than using a cropped page with a nonzero media-box origin.
        context.translateBy(x: -144, y: -132)
        drawMark(context, ink: red)
    }
    try writePDF(assets.appendingPathComponent("AppLogo.imageset/AppLogo\(suffix).pdf"), bounds: CGRect(x: 0, y: 0, width: 1024, height: 1024)) { context in
        context.setFillColor(red)
        context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024), cornerWidth: 226, cornerHeight: 226, transform: nil))
        context.fillPath()
        drawMark(context, ink: ivory)
    }
}

let sourceBounds = operatorPath.boundingBoxOfPath
let svgScale = operatorHeight / sourceBounds.height
let svgX = operatorCenterX - sourceBounds.width * svgScale / 2
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="144 132 736 760" role="img" aria-label="Red TV / CS">
  <g fill="#FF2442" transform="translate(512 512) scale(1.12) translate(-525 -512)">
    <path fill-rule="evenodd" d="\(rData) M402 558H626Q658 558 658 590V740Q658 772 626 772H402Q370 772 370 740V590Q370 558 402 558Z" transform="translate(0 1024) scale(1 -1)"/>
    <path d="\(operatorData)" transform="translate(\(svgX) \(1024 - operatorBottom - operatorHeight)) scale(\(svgScale)) translate(\(-sourceBounds.minX) \(-sourceBounds.minY))"/>
  </g>
</svg>
"""
try svg.write(to: branding.appendingPathComponent("Logo.svg"), atomically: true, encoding: .utf8)

func centeredText(_ text: String, at center: CGPoint, size: CGFloat, weight: NSFont.Weight, ink: CGColor, tracking: CGFloat = 0) {
    let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor(cgColor: ink)!, .kern: tracking])
    let measured = string.size()
    string.draw(at: CGPoint(x: center.x - measured.width / 2, y: center.y - measured.height / 2))
}

// Shareable artwork previews. The actual launch screen uses Auto Layout below.
for dark in [false, true] {
    try writePNG(branding.appendingPathComponent(dark ? "LaunchScreen-Dark.png" : "LaunchScreen-Light.png"), width: 1179, height: 2556) { context in
        context.scaleBy(x: 3, y: 3)
        context.setFillColor(dark ? darkPaper : color(0xF7F8FA))
        context.fill(CGRect(x: 0, y: 0, width: 393, height: 852))
        context.saveGState()
        context.translateBy(x: 116.5, y: 416)
        context.scaleBy(x: 160 / 736, y: 166 / 760)
        context.translateBy(x: -144, y: -132)
        drawMark(context, ink: red)
        context.restoreGState()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        centeredText("Red TV", at: CGPoint(x: 196.5, y: 384), size: 32, weight: .heavy, ink: dark ? darkInk : color(0x181A20), tracking: -0.8)
        centeredText("CS2 赛事 · 每一局都值得关注", at: CGPoint(x: 196.5, y: 342), size: 12, weight: .regular, ink: dark ? color(0x7E8592) : color(0x858A96))
        centeredText("Red TV · CS2", at: CGPoint(x: 196.5, y: 65), size: 9, weight: .semibold, ink: dark ? color(0x6E7582) : color(0xA1A5AF), tracking: 2)
        NSGraphicsContext.restoreGraphicsState()
    }
}
try writePNG(branding.appendingPathComponent("Preview.png"), width: 1440, height: 900) { context in
    context.setFillColor(color(0x202B38))
    context.fill(CGRect(x: 0, y: 0, width: 1440, height: 900))
    let images: [(URL, CGRect, CGFloat)] = [
        (assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png"), CGRect(x: 94, y: 350, width: 320, height: 320), 72),
        (branding.appendingPathComponent("LaunchScreen-Light.png"), CGRect(x: 520, y: 92, width: 332, height: 720), 28),
        (branding.appendingPathComponent("LaunchScreen-Dark.png"), CGRect(x: 960, y: 92, width: 332, height: 720), 28)
    ]
    for (url, rect, radius) in images {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
        context.saveGState()
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        context.draw(image, in: rect)
        context.restoreGState()
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    centeredText("Red TV", at: CGPoint(x: 254, y: 795), size: 42, weight: .heavy, ink: darkInk, tracking: 1)
    centeredText("CS2 MATCH CENTER", at: CGPoint(x: 254, y: 744), size: 16, weight: .regular, ink: color(0xA4ADBA), tracking: 1)
    centeredText("R 字标 · 电视窗口 · CS 剪影", at: CGPoint(x: 254, y: 294), size: 17, weight: .medium, ink: darkInk)
    centeredText("每一局，都值得关注。", at: CGPoint(x: 254, y: 254), size: 15, weight: .regular, ink: color(0xA4ADBA))
    centeredText("系统浅色模式", at: CGPoint(x: 686, y: 50), size: 15, weight: .medium, ink: color(0xA4ADBA))
    centeredText("系统深色模式", at: CGPoint(x: 1126, y: 50), size: 15, weight: .medium, ink: color(0xA4ADBA))
    NSGraphicsContext.restoreGraphicsState()
}
print("Generated Red TV icons, vector logos and launch artwork in Assets.xcassets and Branding/.")

// Inspect the real downscaled desktop icon at common iOS display sizes.
try writePNG(branding.appendingPathComponent("Icon-Sizes.png"), width: 900, height: 300) { context in
    context.setFillColor(color(0xF7F8FA)); context.fill(CGRect(x: 0, y: 0, width: 900, height: 300))
    let source = CGImageSourceCreateWithURL(assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png") as CFURL, nil)!
    let original = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    for (index, size) in [29, 44, 60, 120].enumerated() {
        let center = CGFloat(index) * 210 + 135
        let side = CGFloat(size)
        let rect = CGRect(x: center - side / 2, y: 160 - side / 2, width: side, height: side)
        context.saveGState(); context.addPath(CGPath(roundedRect: rect, cornerWidth: side * 0.225, cornerHeight: side * 0.225, transform: nil)); context.clip(); context.interpolationQuality = .high; context.draw(original, in: rect); context.restoreGState()
    }
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    for (index, size) in [29, 44, 60, 120].enumerated() { centeredText("\(size) pt", at: CGPoint(x: CGFloat(index) * 210 + 135, y: 50), size: 17, weight: .medium, ink: color(0x6D7380)) }
    NSGraphicsContext.restoreGraphicsState()
}
