// header.swift <out.png> <W> <H> <safeX> <safeY> <safeW> <safeH> <leftShot.png> <rightShot.png> <phrase> [--guides]
// `\n` in the phrase forces a line break.
// App Store product page header / universal asset: copy + hero emoji in the art safe area, tilted
// screenshots, animals and confetti in the auxiliary area. Coordinates are top-left based (Apple's templates).
import AppKit
let a = CommandLine.arguments
let W = Int(a[2])!, H = Int(a[3])!
let safe = CGRect(x: Double(a[4])!, y: Double(H) - Double(a[5])! - Double(a[7])!, width: Double(a[6])!, height: Double(a[7])!)
let guides = a.contains("--guides")
let s = safe.height / 962   // scale relative to the universal safe area

let yellow = NSColor(srgbRed: 1, green: 0xD4/255, blue: 0x3B/255, alpha: 1)
let ink = NSColor(srgbRed: 0x1E/255, green: 0x16/255, blue: 0x40/255, alpha: 1)
let fills: [NSColor] = [0xFF5A87, 0x6B3FE6, 0x16C8B0, 0xFF9F43, 0x4D8BFF].map {
    NSColor(srgbRed: CGFloat(($0 >> 16) & 0xFF)/255, green: CGFloat(($0 >> 8) & 0xFF)/255, blue: CGFloat($0 & 0xFF)/255, alpha: 1)
}

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
ctx.setFillColor(yellow.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

// Confetti: seeded, kept off the safe area so the copy stays clean.
var seed: UInt64 = 42
func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
let keepOut = safe.insetBy(dx: -80 * s, dy: -60 * s)
var placed = 0
while placed < 70 {
    let p = CGPoint(x: rnd() * Double(W), y: rnd() * Double(H))
    if keepOut.contains(p) { continue }
    let r = (14 + rnd() * 22) * s
    ctx.saveGState()
    ctx.translateBy(x: p.x, y: p.y); ctx.rotate(by: rnd() * .pi)
    ctx.setFillColor(fills[Int(rnd() * Double(fills.count))].cgColor)
    if rnd() < 0.5 { ctx.fillEllipse(in: CGRect(x: -r, y: -r, width: 2*r, height: 2*r)) }
    else { ctx.addPath(CGPath(roundedRect: CGRect(x: -r*1.6, y: -r*0.55, width: r*3.2, height: r*1.1), cornerWidth: r*0.5, cornerHeight: r*0.5, transform: nil)); ctx.fillPath() }
    ctx.restoreGState()
    placed += 1
}

// Tilted phones with the app's ink border and hard shadow.
func load(_ p: String) -> CGImage { NSImage(contentsOfFile: p)!.cgImage(forProposedRect: nil, context: nil, hints: nil)! }
func phone(_ path: String, center: CGPoint, height: CGFloat, angle: CGFloat) {
    let img = load(path)
    let h = height, w = h * CGFloat(img.width) / CGFloat(img.height)
    let rect = CGRect(x: -w/2, y: -h/2, width: w, height: h)
    let radius = 150 * h / CGFloat(img.height), border = 16 * s
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: angle * .pi / 180)
    let outer = rect.insetBy(dx: -border, dy: -border)
    ctx.setFillColor(ink.cgColor)
    ctx.addPath(CGPath(roundedRect: outer.offsetBy(dx: 22 * s, dy: -26 * s), cornerWidth: radius + border, cornerHeight: radius + border, transform: nil)); ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: outer, cornerWidth: radius + border, cornerHeight: radius + border, transform: nil)); ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(img, in: rect)
    ctx.restoreGState()
}
let phoneH = safe.height * 1.55
let gap = 520 * s
phone(a[8], center: CGPoint(x: safe.minX - gap, y: safe.midY - 40 * s), height: phoneH, angle: 8)
phone(a[9], center: CGPoint(x: safe.maxX + gap, y: safe.midY - 40 * s), height: phoneH, angle: -8)

// Emoji helpers.
func emoji(_ e: String, size: CGFloat, center: CGPoint, angle: CGFloat = 0) {
    let str = NSAttributedString(string: e, attributes: [.font: NSFont(name: "Apple Color Emoji", size: size)!])
    let b = str.size()
    ctx.saveGState(); ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: angle * .pi / 180)
    str.draw(at: CGPoint(x: -b.width/2, y: -b.height/2)); ctx.restoreGState()
}
// Supporting animals out in the auxiliary area.
emoji("🐘", size: 300 * s, center: CGPoint(x: safe.minX - gap - 640 * s, y: safe.maxY + 120 * s), angle: -10)
emoji("🦒", size: 300 * s, center: CGPoint(x: safe.maxX + gap + 640 * s, y: safe.minY - 40 * s), angle: 8)

// Safe area: hero hippo in a cream badge, then the headline.
let badgeR = 190 * s
let badgeC = CGPoint(x: safe.midX, y: safe.maxY - badgeR - 20 * s)
ctx.setFillColor(ink.cgColor)
ctx.fillEllipse(in: CGRect(x: badgeC.x - badgeR + 14*s, y: badgeC.y - badgeR - 18*s, width: 2*badgeR, height: 2*badgeR))
ctx.fillEllipse(in: CGRect(x: badgeC.x - badgeR - 12*s, y: badgeC.y - badgeR - 12*s, width: 2*badgeR + 24*s, height: 2*badgeR + 24*s))
ctx.setFillColor(NSColor(srgbRed: 1, green: 0xF4/255, blue: 0xCC/255, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: badgeC.x - badgeR, y: badgeC.y - badgeR, width: 2*badgeR, height: 2*badgeR))
emoji("🦛", size: 230 * s, center: CGPoint(x: badgeC.x, y: badgeC.y - 6 * s))

// Headline: the largest size up to 190 (universal scale) where every line fits the safe area unwrapped.
let phrase = a[10].replacingOccurrences(of: "\\n", with: "\n")
let textBox = CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: badgeC.y - badgeR - 30 * s - safe.minY)
let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineHeightMultiple = 0.9
var size = 190 * s
var text = NSAttributedString()
repeat {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded)!, size: size)!
    text = NSAttributedString(string: phrase, attributes: [.font: font, .foregroundColor: ink, .paragraphStyle: para, .kern: -2 * s])
    let widest = phrase.components(separatedBy: "\n").map {
        NSAttributedString(string: $0, attributes: [.font: font, .kern: -2 * s]).size().width
    }.max() ?? 0
    let tall = text.boundingRect(with: CGSize(width: 10_000, height: 10_000), options: [.usesLineFragmentOrigin]).height
    if widest <= textBox.width - 20 * s && tall <= textBox.height { break }
    size -= 4 * s
} while size > 60 * s
let ts = text.boundingRect(with: CGSize(width: textBox.width, height: 10_000), options: [.usesLineFragmentOrigin]).size
text.draw(with: CGRect(x: textBox.minX, y: textBox.midY - ts.height/2, width: textBox.width, height: ts.height), options: [.usesLineFragmentOrigin])

if guides {
    ctx.setStrokeColor(NSColor.red.cgColor); ctx.setLineWidth(6); ctx.stroke(safe)
}
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[1]))
