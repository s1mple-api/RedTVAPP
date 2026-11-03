import UIKit

@MainActor final class ArenaImages {
    static let shared = ArenaImages()
    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private init() {
        cache.totalCostLimit = 24 * 1024 * 1024
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        session = URLSession(configuration: config)
    }
    static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("https://data.wanmei.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://data.wanmei.com", forHTTPHeaderField: "Origin")
        return request
    }
    static func foregroundBrightness(_ image: UIImage) -> Double? {
        guard let source = image.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: 16, height: 16))
            return true
        }
        guard drawn else { return nil }
        var light = 0.0, alpha = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            light += 0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])
            alpha += Double(pixels[i + 3])
        }
        return alpha > 0 ? light / alpha : nil
    }
    func image(at url: URL) async -> UIImage? {
        if let image = cache.object(forKey: url as NSURL) { return image }
        do {
            let (data, response) = try await session.data(for: Self.request(for: url))
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 8 * 1024 * 1024, let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
            return image
        } catch { return nil }
    }
}
