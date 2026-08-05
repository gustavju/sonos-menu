import SwiftUI
import AppKit

struct ArtworkThemeExtractor {
    
    private let sampleSize = 64
    private let bucketSize = 8 // 32 buckets per channel
    
    struct Bucket: Hashable {
        let r: Int
        let g: Int
        let b: Int
    }
    
    func extract(from image: NSImage) -> ArtworkTheme {
        guard let pixels = samplePixels(from: image) else {
            return .default
        }
        
        let vibrant = findVibrantColor(in: pixels)
        return buildTheme(from: vibrant)
    }
    
    // MARK: - Sampling
    
    private func samplePixels(from image: NSImage) -> [UInt8]? {
        
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        
        context.draw(
            cgImage,
            in: CGRect(
                x: 0,
                y: 0,
                width: sampleSize,
                height: sampleSize
            )
        )
        
        guard let data = context.data else {
            return nil
        }
        
        let count = sampleSize * sampleSize * 4
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: count)
        
        return Array(UnsafeBufferPointer(start: buffer, count: count))
    }
    
    
    // MARK: - Vibrant extraction
    
    private func findVibrantColor(in pixels: [UInt8]) -> SIMD3<Double> {
        
        var buckets: [Bucket: Int] = [:]
        
        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            
            let r = Double(pixels[pixel]) / 255
            let g = Double(pixels[pixel + 1]) / 255
            let b = Double(pixels[pixel + 2]) / 255
            
            let hsv = rgbToHSV(r: r, g: g, b: b)
            
            guard hsv.v > 0.15,
                  hsv.v < 0.9,
                  hsv.s > 0.25 else {
                continue
            }
            
            let bucket = Bucket(
                r: Int(pixels[pixel]) / bucketSize,
                g: Int(pixels[pixel + 1]) / bucketSize,
                b: Int(pixels[pixel + 2]) / bucketSize
            )
            
            buckets[bucket, default: 0] += 1
        }
        
        guard
            let winner = buckets.max(by: { $0.value < $1.value }),
            winner.value > 20
        else {
            return SIMD3(0.45, 0.45, 0.45)
        }
        
        let r = (Double(winner.key.r * bucketSize) + Double(bucketSize) / 2) / 255
        let g = (Double(winner.key.g * bucketSize) + Double(bucketSize) / 2) / 255
        let b = (Double(winner.key.b * bucketSize) + Double(bucketSize) / 2) / 255
        
        return boostSaturation(
            color: SIMD3(r, g, b),
            amount: 1.15
        )
    }
    
    // MARK: - Theme generation
    
    private func buildTheme(from vibrantRGB: SIMD3<Double>) -> ArtworkTheme {
        
        let vibrant = Color(
            red: vibrantRGB.x,
            green: vibrantRGB.y,
            blue: vibrantRGB.z
        )
        
        let background = shade(vibrantRGB, factor: 0.20)
        
        let secondaryBackground = shade(vibrantRGB, factor: 0.32)
        
        let luma =
        0.299 * vibrantRGB.x +
        0.587 * vibrantRGB.y +
        0.114 * vibrantRGB.z
        
        let foreground: Color = luma > 0.55 ? .black : .white
        
        return ArtworkTheme(
            vibrant: vibrant,
            background: background,
            secondaryBackground: secondaryBackground,
            foreground: foreground
        )
    }
    
    // MARK: - Color helpers
    
    private func shade(
        _ color: SIMD3<Double>,
        factor: Double
    ) -> Color {
        
        Color(
            red: color.x * factor,
            green: color.y * factor,
            blue: color.z * factor
        )
    }
    
    private func boostSaturation(
        color: SIMD3<Double>,
        amount: Double
    ) -> SIMD3<Double> {
        
        var hsv = rgbToHSV(
            r: color.x,
            g: color.y,
            b: color.z
        )
        
        hsv.s = min(hsv.s * amount, 1.0)
        
        return hsvToRGB(
            h: hsv.h,
            s: hsv.s,
            v: hsv.v
        )
    }
    
    private func rgbToHSV(
        r: Double,
        g: Double,
        b: Double
    ) -> (h: Double, s: Double, v: Double) {
        
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        let v = maxC
        let s = maxC == 0 ? 0 : delta / maxC
        
        var h = 0.0
        
        if delta != 0 {
            if maxC == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxC == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            
            h /= 6
        }
        
        return (h, s, v)
    }
    
    private func hsvToRGB(
        h: Double,
        s: Double,
        v: Double
    ) -> SIMD3<Double> {
        
        guard s > 0 else {
            return SIMD3(v, v, v)
        }
        
        let i = floor(h * 6)
        let f = h * 6 - i
        
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        
        switch Int(i) % 6 {
        case 0: return SIMD3(v, t, p)
        case 1: return SIMD3(q, v, p)
        case 2: return SIMD3(p, v, t)
        case 3: return SIMD3(p, q, v)
        case 4: return SIMD3(t, p, v)
        default: return SIMD3(v, p, q)
        }
    }
}
