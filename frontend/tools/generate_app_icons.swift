// Run from the repository root on macOS:
// swift -module-cache-path /private/tmp/planit-swift-cache tools/generate_app_icons.swift
import Foundation
import CoreGraphics
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("assets/images/planit_app_icon.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Cannot read source app icon")
}

func png(size: Int, opaque: Bool = false, inset: Double = 0) throws -> Data {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: alpha.rawValue
    ) else { fatalError("Cannot create icon context") }
    let side = Double(size)
    if opaque {
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    }
    context.interpolationQuality = .high
    let padding = side * inset
    context.draw(image, in: CGRect(x: padding, y: padding, width: side - 2 * padding, height: side - 2 * padding))
    let data = NSMutableData()
    guard let output = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil),
          let rendered = context.makeImage() else { fatalError("Cannot encode icon") }
    CGImageDestinationAddImage(output, rendered, nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Cannot finish icon") }
    return data as Data
}

func write(_ path: String, size: Int, opaque: Bool = false, inset: Double = 0) throws {
    try png(size: size, opaque: opaque, inset: inset).write(to: root.appendingPathComponent(path))
}

for platform in ["ios", "macos"] {
    let directory = "\(platform)/Runner/Assets.xcassets/AppIcon.appiconset"
    let contents = try Data(contentsOf: root.appendingPathComponent("\(directory)/Contents.json"))
    let catalog = try JSONSerialization.jsonObject(with: contents) as! [String: Any]
    for entry in catalog["images"] as! [[String: String]] {
        guard let filename = entry["filename"], let size = entry["size"], let scale = entry["scale"] else { continue }
        let pixels = Int(Double(size.components(separatedBy: "x")[0])! * Double(scale.replacingOccurrences(of: "x", with: ""))!)
        try write("\(directory)/\(filename)", size: pixels, opaque: platform == "ios")
    }
}

for (density, size) in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
    try write("android/app/src/main/res/mipmap-\(density)/ic_launcher.png", size: size)
}
try write("web/favicon.png", size: 32)
for size in [192, 512] {
    try write("web/icons/Icon-\(size).png", size: size)
    // Keep the complete square artwork inside the maskable icon safe circle.
    try write("web/icons/Icon-maskable-\(size).png", size: size, opaque: true, inset: 0.22)
}

// Windows ICO: PNG payloads at multiple resolutions, including 256px.
func littleEndian(_ value: UInt32, bytes: Int) -> Data {
    Data((0..<bytes).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) })
}
let sizes = [16, 24, 32, 48, 64, 128, 256]
let payloads = try sizes.map { try png(size: $0) }
var ico = Data([0, 0, 1, 0])
ico.append(littleEndian(UInt32(sizes.count), bytes: 2))
var offset = 6 + 16 * sizes.count
for (size, data) in zip(sizes, payloads) {
    let dimension = UInt8(size == 256 ? 0 : size)
    ico.append(contentsOf: [dimension, dimension, 0, 0, 1, 0, 32, 0])
    ico.append(littleEndian(UInt32(data.count), bytes: 4))
    ico.append(littleEndian(UInt32(offset), bytes: 4))
    offset += data.count
}
for data in payloads { ico.append(data) }
try ico.write(to: root.appendingPathComponent("windows/runner/resources/app_icon.ico"))
print("Generated Android, iOS, macOS, Windows and web icons.")
