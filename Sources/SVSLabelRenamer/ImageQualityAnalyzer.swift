import CoreGraphics
import Foundation

enum ImageQualityAnalyzer {
    static let algorithmVersion = "overview-v1"

    /// Conservative screening of the low-magnification WSI overview. The result is
    /// intentionally a review aid, not a diagnostic or scanner-validation result.
    static func assess(_ image: CGImage, maximumDimension: Int = 1200) -> QualityAssessment? {
        guard image.width > 2, image.height > 2 else { return nil }

        let scale = min(1, Double(maximumDimension) / Double(max(image.width, image.height)))
        let width = max(3, Int((Double(image.width) * scale).rounded()))
        let height = max(3, Int((Double(image.height) * scale).rounded()))
        let bytesPerRow = width * 4
        var rgba = [UInt8](repeating: 255, count: height * bytesPerRow)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminance = [Double](repeating: 1, count: width * height)
        var tissue = [Bool](repeating: false, count: width * height)
        var tissueCount = 0
        var sum = 0.0
        var sumSquares = 0.0
        var darkCount = 0
        var brightCount = 0
        var globalSum = 0.0
        var globalDarkCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let pixel = y * bytesPerRow + x * 4
                let red = Double(rgba[pixel]) / 255
                let green = Double(rgba[pixel + 1]) / 255
                let blue = Double(rgba[pixel + 2]) / 255
                let value = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                let chroma = max(red, green, blue) - min(red, green, blue)
                let index = y * width + x
                luminance[index] = value
                globalSum += value
                if value < 0.10 { globalDarkCount += 1 }

                // Exclude white glass/background and almost-black borders. Pale H&E
                // and IHC tissue is retained through the chroma branch.
                let isTissue = value > 0.04 && (value < 0.94 || chroma > 0.035)
                tissue[index] = isTissue
                guard isTissue else { continue }
                tissueCount += 1
                sum += value
                sumSquares += value * value
                if value < 0.12 { darkCount += 1 }
                if value > 0.93 { brightCount += 1 }
            }
        }

        let total = width * height
        let coverage = Double(tissueCount) / Double(total)
        guard tissueCount > 0 else {
            let globalMean = globalSum / Double(total)
            let globalDarkFraction = Double(globalDarkCount) / Double(total)
            var flags: [QualityFlag] = [.littleTissue]
            if globalMean < 0.10 && globalDarkFraction > 0.90 { flags.append(.tooDark) }
            return QualityAssessment(
                tissueCoverage: 0,
                brightness: globalMean,
                contrast: 0,
                sharpness: 0,
                edgeFraction: 0,
                flags: flags
            )
        }

        let mean = sum / Double(tissueCount)
        let variance = max(0, sumSquares / Double(tissueCount) - mean * mean)
        let contrast = sqrt(variance)

        var laplacianSquares = 0.0
        var laplacianCount = 0
        var edgeCount = 0
        if tissueCount >= 25 {
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let index = y * width + x
                    guard tissue[index], tissue[index - 1], tissue[index + 1],
                          tissue[index - width], tissue[index + width] else { continue }
                    let laplacian = 4 * luminance[index]
                        - luminance[index - 1] - luminance[index + 1]
                        - luminance[index - width] - luminance[index + width]
                    laplacianSquares += laplacian * laplacian
                    laplacianCount += 1
                    if abs(laplacian) * 255 > 8 { edgeCount += 1 }
                }
            }
        }
        let sharpness = laplacianCount > 0
            ? sqrt(laplacianSquares / Double(laplacianCount)) * 100
            : 0
        let edgeFraction = laplacianCount > 0
            ? Double(edgeCount) / Double(laplacianCount)
            : 0

        let darkFraction = Double(darkCount) / Double(tissueCount)
        let brightFraction = Double(brightCount) / Double(tissueCount)
        var flags: [QualityFlag] = []
        if coverage < 0.01 { flags.append(.littleTissue) }
        if coverage >= 0.01 && mean < 0.15 && darkFraction > 0.50 { flags.append(.tooDark) }
        if coverage >= 0.01 && mean > 0.96 && contrast < 0.01 && brightFraction > 0.95 {
            flags.append(.tooBright)
        }
        if coverage >= 0.03 && contrast < 0.008 { flags.append(.lowContrast) }
        // Keep this deliberately conservative: only gross loss of edge energy is
        // flagged. A low-resolution overview cannot certify microscopic focus.
        if coverage >= 0.03 && contrast >= 0.035 && laplacianCount >= 5_000
            && sharpness < 0.55 && edgeFraction < 0.002 {
            flags.append(.lowOverviewDetail)
        }

        return QualityAssessment(
            tissueCoverage: coverage,
            brightness: mean,
            contrast: contrast,
            sharpness: sharpness,
            edgeFraction: edgeFraction,
            flags: flags
        )
    }
}
