import CoreGraphics
import Foundation

/// Screenshots sized for a model to read. A Retina capture has 4x the pixels of what's on screen,
/// and models bill images by pixel area, so a full-resolution paste costs far more context than it needs.
public enum AgentSize {
    /// The longest edge Claude reads without shrinking the image first.
    public static let maxEdge: CGFloat = 1568

    /// One pixel per screen point, then no edge longer than `maxEdge`. Tall scrolling captures
    /// only have their width capped, so a long page doesn't shrink to an unreadable strip.
    public static func size(pixels: CGSize, points: CGSize) -> CGSize {
        var w = min(pixels.width, points.width), h = min(pixels.height, points.height)
        let tall = h > w * 3
        let fit = tall ? maxEdge / w : maxEdge / max(w, h)
        if fit < 1 { w *= fit; h *= fit }
        return CGSize(width: max(1, w.rounded()), height: max(1, h.rounded()))
    }

    /// `image` resized for a model, or `image` itself when it's already small enough.
    public static func resize(_ image: CGImage, points: CGSize) -> CGImage {
        let target = size(pixels: CGSize(width: image.width, height: image.height), points: points)
        let w = Int(target.width), h = Int(target.height)
        guard w < image.width || h < image.height else { return image }
        let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }
}
