import AppKit
let output = CommandLine.arguments[1]
for (name, size) in [("AppIcon60x60@2x.png",120), ("AppIcon60x60@3x.png",180), ("AppIcon76x76@2x.png",152), ("AppIcon83.5x83.5@2x.png",167), ("AppIcon1024.png",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let s = CGFloat(size)
    NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.13, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x:0,y:0,width:s,height:s)).fill()
    let orange = NSColor(calibratedRed:1,green:0.64,blue:0.23,alpha:1)
    orange.setFill()
    NSBezierPath(ovalIn: NSRect(x:s*0.28,y:s*0.25,width:s*0.44,height:s*0.44)).fill()
    NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.13, alpha: 1).setFill()
    NSBezierPath(rect:NSRect(x:0,y:0,width:s,height:s*0.42)).fill()
    orange.setStroke()
    let horizon=NSBezierPath(); horizon.lineWidth=s*0.045; horizon.lineCapStyle = .round
    horizon.move(to:NSPoint(x:s*0.18,y:s*0.4)); horizon.line(to:NSPoint(x:s*0.82,y:s*0.4)); horizon.stroke()
    for angle in [30.0, 60.0, 90.0, 120.0, 150.0] {
        let a=CGFloat(angle * .pi / 180)
        let ray=NSBezierPath(); ray.lineWidth=s*0.035; ray.lineCapStyle = .round
        ray.move(to:NSPoint(x:s*0.5+cos(a)*s*0.31,y:s*0.47+sin(a)*s*0.31))
        ray.line(to:NSPoint(x:s*0.5+cos(a)*s*0.39,y:s*0.47+sin(a)*s*0.39)); ray.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output).appendingPathComponent(name))
}
