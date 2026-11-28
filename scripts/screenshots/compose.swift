// compose.swift <raw.png> <caption> <out.png> [statusBarSource.png]
import AppKit
let a = CommandLine.arguments
let W = 1320, H = 2868
let yellow = NSColor(srgbRed: 1, green: 0xD4/255, blue: 0x3B/255, alpha: 1)
let ink = NSColor(srgbRed: 0x1E/255, green: 0x16/255, blue: 0x40/255, alpha: 1)

func load(_ p: String) -> CGImage { NSImage(contentsOfFile: p)!.cgImage(forProposedRect: nil, context: nil, hints: nil)! }
var shot = load(a[1])
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

// Patch a clean status bar over content that scrolled under it.
if a.count > 4 {
    let ctx = CGContext(data: nil, width: shot.width, height: shot.height, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(shot, in: CGRect(x: 0, y: 0, width: shot.width, height: shot.height))
    let bar = 190, cover = 325
    // Below the status bar, cover the partly scrolled-off tile with the background colour.
    ctx.setFillColor(CGColor(srgbRed: 1, green: 0xD4/255, blue: 0x3B/255, alpha: 1))
    ctx.fill(CGRect(x: 0, y: shot.height - cover, width: shot.width, height: cover))
    let src = load(a[4]).cropping(to: CGRect(x: 0, y: 0, width: shot.width, height: bar))!
    ctx.draw(src, in: CGRect(x: 0, y: shot.height - bar, width: shot.width, height: bar))
    shot = ctx.makeImage()!
}

let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(yellow.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

// Caption: SF Pro Rounded Heavy, centred in the top band.
let captionTop: CGFloat = 170, captionHeight: CGFloat = 400
var font = NSFont.systemFont(ofSize: 112, weight: .heavy)
font = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded)!, size: 112)!
let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineHeightMultiple = 0.95
let text = NSAttributedString(string: a[2].replacingOccurrences(of: "\\n", with: "\n"), attributes: [.font: font, .foregroundColor: ink, .paragraphStyle: para, .kern: -1])
let box = CGSize(width: 1160, height: captionHeight)
let size = text.boundingRect(with: box, options: [.usesLineFragmentOrigin]).size
text.draw(with: CGRect(x: (CGFloat(W) - 1160) / 2, y: CGFloat(H) - captionTop - captionHeight/2 - size.height/2, width: 1160, height: size.height), options: [.usesLineFragmentOrigin])

// Screenshot: scaled, rounded, ink border with the app's hard drop shadow.
let top = captionTop + captionHeight + 40
let sh = CGFloat(H) - top - 150
let scale = sh / CGFloat(shot.height)
let sw = CGFloat(shot.width) * scale
let rect = CGRect(x: (CGFloat(W) - sw) / 2, y: 150, width: sw, height: sh)
let radius: CGFloat = 150 * scale, border: CGFloat = 14
let outer = rect.insetBy(dx: -border, dy: -border)
ctx.setFillColor(ink.cgColor)
ctx.addPath(CGPath(roundedRect: outer.offsetBy(dx: 18, dy: -22), cornerWidth: radius + border, cornerHeight: radius + border, transform: nil)); ctx.fillPath()
ctx.addPath(CGPath(roundedRect: outer, cornerWidth: radius + border, cornerHeight: radius + border, transform: nil)); ctx.fillPath()
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.clip()
ctx.interpolationQuality = .high
ctx.draw(shot, in: rect)
ctx.restoreGState()

let out = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))
