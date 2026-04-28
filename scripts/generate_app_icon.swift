#!/usr/bin/env swift
import AppKit
import CoreGraphics
import CoreText

// Triskill app icon generator
// Usage: swift generate_app_icon.swift <output_1024.png>

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_app_icon.swift <output.png>\n", stderr)
    exit(1)
}
let outPath = CommandLine.arguments[1]

let size: CGFloat = 1024
let inset: CGFloat = 100               // 824 内容方块
let cornerRadius: CGFloat = 185        // macOS Big Sur squircle 近似
let canvas = CGRect(x: 0, y: 0, width: size, height: size)
let body = CGRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let center = CGPoint(x: size/2, y: size/2)

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil,
    width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// 翻转坐标系，让原点在左下，y 向上（CG 默认就是，但显式声明便于阅读）
ctx.interpolationQuality = .high
ctx.setShouldAntialias(true)
ctx.setAllowsAntialiasing(true)

// ---- 1. squircle 底：深紫到深蓝纵向渐变 ----
let bgPath = CGPath(
    roundedRect: body,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()

let bgGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.13, green: 0.10, blue: 0.22, alpha: 1.0),  // 顶部深紫
        CGColor(red: 0.07, green: 0.07, blue: 0.14, alpha: 1.0),  // 底部近黑
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// 顶部高光，给底面一点立体感
let highlight = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    highlight,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: 0, y: size * 0.55),
    options: []
)
ctx.restoreGState()

// ---- 2. 三色环 ----
// 三家家族色：Claude 橙 / Codex 青绿 / Cursor 紫
let claudeColor = CGColor(red: 0.95, green: 0.55, blue: 0.36, alpha: 0.92)
let codexColor  = CGColor(red: 0.20, green: 0.78, blue: 0.62, alpha: 0.92)
let cursorColor = CGColor(red: 0.62, green: 0.45, blue: 1.00, alpha: 0.92)

let ringRadius: CGFloat = 250
let ringStroke: CGFloat = 46
let ringOffset: CGFloat = 130

// 正三角排布，顶点朝上
let topC   = CGPoint(x: center.x,                                    y: center.y + ringOffset * 0.95)
let leftC  = CGPoint(x: center.x - ringOffset * sqrt(3) / 2,         y: center.y - ringOffset * 0.50)
let rightC = CGPoint(x: center.x + ringOffset * sqrt(3) / 2,         y: center.y - ringOffset * 0.50)

func drawRing(center: CGPoint, color: CGColor) {
    let rect = CGRect(
        x: center.x - ringRadius,
        y: center.y - ringRadius,
        width: ringRadius * 2,
        height: ringRadius * 2
    )
    ctx.setStrokeColor(color)
    ctx.setLineWidth(ringStroke)
    ctx.addEllipse(in: rect)
    ctx.strokePath()
}

ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
// screen 混合让交叠处自然变亮，体现"聚合"语义
ctx.setBlendMode(.screen)
drawRing(center: topC,   color: claudeColor)
drawRing(center: leftC,  color: codexColor)
drawRing(center: rightC, color: cursorColor)
ctx.restoreGState()

// ---- 3. 中央衬线 S（用 glyph path 严格居中）----
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()

let fontSize: CGFloat = 380
let ctFont = CTFontCreateWithName(("Georgia-Bold" as CFString), fontSize, nil)

// 取 "S" 这个 glyph 的实际描边路径，而不是排版盒，得到真正视觉中心
var unichars: [UniChar] = Array("S".utf16)
var glyphs: [CGGlyph] = [0]
guard CTFontGetGlyphsForCharacters(ctFont, &unichars, &glyphs, 1) else {
    fputs("glyph lookup failed\n", stderr); exit(4)
}
guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyphs[0], nil) else {
    fputs("glyph path failed\n", stderr); exit(5)
}
let glyphBounds = glyphPath.boundingBox

// 把 glyph 平移到画布正中心
var transform = CGAffineTransform.identity
    .translatedBy(
        x: center.x - glyphBounds.midX,
        y: center.y - glyphBounds.midY
    )
guard let centeredPath = glyphPath.copy(using: &transform) else {
    fputs("path transform failed\n", stderr); exit(6)
}

// 投影：先画一层模糊的暗影，让 S 浮在三色环之上
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -8),
    blur: 22,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55)
)
ctx.addPath(centeredPath)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
ctx.fillPath()
ctx.restoreGState()

ctx.restoreGState()

// ---- 输出 PNG ----
guard let cgImage = ctx.makeImage() else {
    fputs("makeImage failed\n", stderr)
    exit(2)
}
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("png encode failed\n", stderr)
    exit(3)
}
try data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
