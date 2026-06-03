#!/usr/bin/swift
// Generates AppIcon.iconset/icon_512x512@2x.png (1024×1024).
// Run from the project root:  swift scripts/generate_icon.swift
// Then: iconutil -c icns AppIcon.iconset -o Resources/AppIcon.icns

import AppKit

let size: CGFloat = 1024
let cx = size / 2
let cy = size / 2

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// ── Background: dark rounded rectangle ──────────────────────────────────────
NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
             xRadius: 230, yRadius: 230).fill()

// ── Track ring (dim white) ───────────────────────────────────────────────────
let track = NSBezierPath()
track.appendArc(withCenter: NSPoint(x: cx, y: cy),
                radius: 340, startAngle: 0, endAngle: 360, clockwise: false)
track.lineWidth = 72
NSColor(white: 1, alpha: 0.10).setStroke()
track.stroke()

// ── Usage arc: orange, ~75%, clockwise from top (90°) ───────────────────────
// 75% of 360° = 270° → endAngle = 90° − 270° = −180°
let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: cx, y: cy),
              radius: 340, startAngle: 90, endAngle: -180, clockwise: true)
arc.lineWidth = 72
arc.lineCapStyle = .round
NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.10, alpha: 1).setStroke()
arc.stroke()

// ── Inner circle (subtle lighter bg) ────────────────────────────────────────
NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.17, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: cx - 258, y: cy - 258, width: 516, height: 516)).fill()

// ── "C" letterform using two arcs (outer ring minus notch) ──────────────────
// Outer filled arc leaving a notch on the right → looks like "C"
let cOuter: CGFloat = 175
let cInner: CGFloat = 110
let notch: CGFloat = 52   // degrees each side of the right opening

// Outer arc, leaving a gap on the right side
let cShape = NSBezierPath()
cShape.appendArc(withCenter: NSPoint(x: cx, y: cy),
                 radius: cOuter, startAngle: notch, endAngle: 360 - notch,
                 clockwise: false)
// Inner arc back (creates the ring shape)
cShape.appendArc(withCenter: NSPoint(x: cx, y: cy),
                 radius: cInner, startAngle: 360 - notch, endAngle: notch,
                 clockwise: true)
cShape.close()
NSColor(white: 1, alpha: 0.92).setFill()
cShape.fill()

image.unlockFocus()

// ── Write PNG ────────────────────────────────────────────────────────────────
let dir = URL(fileURLWithPath: "AppIcon.iconset")
try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

let cgImg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let rep = NSBitmapImageRep(cgImage: cgImg)
rep.size = NSSize(width: size, height: size)
let data = rep.representation(using: .png, properties: [:])!
let dest = dir.appendingPathComponent("icon_512x512@2x.png")
try! data.write(to: dest)
print("✅ Written \(dest.path)")
