// flatten.swift <in.png> <out.png>: removes the alpha channel (black ground for the Watch).
import AppKit
let src = NSImage(contentsOfFile: CommandLine.arguments[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let ctx = CGContext(data: nil, width: src.width, height: src.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(.black); ctx.fill(CGRect(x: 0, y: 0, width: src.width, height: src.height))
ctx.draw(src, in: CGRect(x: 0, y: 0, width: src.width, height: src.height))
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
