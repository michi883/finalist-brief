// Renders a 1280x720 PNG card for the briefing video. One-off tooling for the
// offline asset pipeline (PLAN.md §10); not used by the app at runtime.
//
// Usage:
//   swift render_card.swift card  <out.png> <eyebrow> <title> <subtitle> <footer>
//   swift render_card.swift lower <out.png> <title> <subtitle>
//
// "card" is a full-frame dark card. "lower" is a transparent frame with a
// lower-third bar, meant to be composited over demo footage with ffmpeg overlay.
import AppKit
import Foundation

let W = 1280.0, H = 720.0
let bg = NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
let accent = NSColor(red: 0.96, green: 0.62, blue: 0.09, alpha: 1)
let fg = NSColor.white
let muted = NSColor(white: 1, alpha: 0.72)

func attrs(_ size: CGFloat, weight: NSFont.Weight, color: NSColor, spacing: CGFloat = 0) -> [NSAttributedString.Key: Any] {
    let p = NSMutableParagraphStyle()
    p.lineBreakMode = .byWordWrapping
    p.lineSpacing = size * 0.18
    var a: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: p,
    ]
    if spacing != 0 { a[.kern] = spacing }
    return a
}

func draw(_ text: String, in rect: NSRect, _ a: [NSAttributedString.Key: Any]) {
    NSAttributedString(string: text, attributes: a).draw(in: rect)
}

func render(to path: String, _ body: () -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    body()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write("usage: render_card.swift card|lower <out.png> ...\n".data(using: .utf8)!)
    exit(2)
}
let kind = args[1], out = args[2]

switch kind {
case "card":
    let eyebrow = args[3], title = args[4]
    let subtitle = args.count > 5 ? args[5] : "", footer = args.count > 6 ? args[6] : ""
    render(to: out) {
        bg.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
        accent.setFill(); NSRect(x: 96, y: H - 118, width: 56, height: 6).fill()
        draw(eyebrow.uppercased(), in: NSRect(x: 96, y: H - 168, width: W - 192, height: 34),
             attrs(20, weight: .semibold, color: accent, spacing: 3))
        draw(title, in: NSRect(x: 96, y: H - 400, width: W - 192, height: 220),
             attrs(58, weight: .bold, color: fg))
        draw(subtitle, in: NSRect(x: 96, y: 150, width: W - 192, height: 150),
             attrs(28, weight: .regular, color: muted))
        draw(footer, in: NSRect(x: 96, y: 64, width: W - 192, height: 40),
             attrs(20, weight: .medium, color: accent))
    }
case "lower":
    let title = args[3], subtitle = args.count > 4 ? args[4] : ""
    render(to: out) {
        NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
        let bar = NSRect(x: 0, y: 0, width: W, height: 132)
        NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 0.86).setFill(); bar.fill()
        accent.setFill(); NSRect(x: 0, y: 0, width: 10, height: 132).fill()
        draw(title, in: NSRect(x: 44, y: 66, width: W - 88, height: 48),
             attrs(30, weight: .bold, color: fg))
        draw(subtitle, in: NSRect(x: 44, y: 22, width: W - 88, height: 40),
             attrs(21, weight: .regular, color: muted))
    }
default:
    FileHandle.standardError.write("unknown kind \(kind)\n".data(using: .utf8)!)
    exit(2)
}
