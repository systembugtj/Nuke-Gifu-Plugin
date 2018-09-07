// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import UIKit
import ImageIO
import Gifu
import Nuke

// MARK: - UIImage Extension
extension UIImage : _ExpressibleByImageLiteral {
    private convenience init!(failableImageLiteral name: String) {
        self.init(named: name)
    }
    
    public convenience init(imageLiteralResourceName name: String) {
        self.init(failableImageLiteral: name)
    }
}

/// Represents animated image data alongside a poster image (first image frame).
public class AnimatedImage: Image {
    public let data: Data
    
    public init(data: Data, poster: CGImage) {
        self.data = data
        super.init(cgImage: poster, scale: 1, orientation: .up)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: "_nk_data") as? Data else {
            return nil
        }
        self.data = data
        super.init(coder: aDecoder)
    }
    
    public override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(data, forKey: "_nk_data")
    }
}

/// Creates instances of `AnimatedImage` class from the given data.
/// Returns `nil` is data doesn't contain an animated GIF.
public class AnimatedImageDecoder: Nuke.ImageDecoding {
    public func decode(data: Data, isFinal: Bool) -> Image? {
        guard AnimatedImageDecoder.isAnimatedGIFData(data) else {
            return nil
        }
        guard let poster = self.posterImage(for: data) else {
            return nil
        }
        return AnimatedImage(data: data, poster: poster)
    }
    
    public init() {
        
    }

    
    private func posterImage(for data: Data) -> CGImage? {
        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        return nil
    }
}


// MARK: - check webp format data.
extension AnimatedImageDecoder {
    public static func isAnimatedGIFData(_ data: Data) -> Bool {
        let sigLength = 3
        if data.count < sigLength {
            return false
        }
        var sig = [UInt8](repeating: 0, count: sigLength)
        (data as NSData).getBytes(&sig, length:sigLength)
        return sig[0] == 0x47 && sig[1] == 0x49 && sig[2] == 0x46
    }
    
    public static func enable() {
        Nuke.ImageDecoderRegistry.shared.register { (context) -> ImageDecoding? in
            AnimatedImageDecoder.enable(context: context)
        }
    }
    
    public static func enable(context: Nuke.ImageDecodingContext) -> Nuke.ImageDecoding? {
        return isAnimatedGIFData(context.data) ? AnimatedImageDecoder() : nil
    }
    
}

/// Simple `Gifu.GIFImageView` wrapper that implement `Nuke.Target` protocol.
///
/// The reason why this is a standalone class and not a simple overridden method
/// from `UIImageView` extension is because declarations from extensions
/// cannot be overridden in Swift (yet).
public class AnimatedImageView: UIView, Nuke.ImageDisplaying {
    
    public let imageView: Gifu.GIFImageView
    
    public init(imageView: Gifu.GIFImageView = Gifu.GIFImageView()) {
        self.imageView = imageView
        super.init(frame: CGRect.zero)
        prepare()
    }

    required public init?(coder aDecoder: NSCoder) {
        self.imageView = Gifu.GIFImageView()
        super.init(coder: aDecoder)
        prepare()
    }

    /// Common init.
    private func prepare() {
        addSubview(imageView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        for attr in [.top, .leading, .bottom, .trailing] as [NSLayoutAttribute] {
            addConstraint(NSLayoutConstraint(item: imageView, attribute: attr, relatedBy: .equal, toItem: self, attribute: attr, multiplier: 1, constant: 0))
        }
    }

    public func prepareForReuse() {
        imageView.prepareForReuse()
        imageView.image = nil
    }
    
    public func display(image: Image?) {
        imageView.prepareForReuse()
        if let image = image as? AnimatedImage {
            imageView.animate(withGIFData: image.data)
        } else {
            imageView.image = image
        }
        /*
        if !isFromMemoryCache {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.duration = 0.25
            animation.fromValue = 0
            animation.toValue = 1
            let layer: CALayer? = imageView.layer // Make compiler happy on OSX
            layer?.add(animation, forKey: "imageTransition")
        }*/
    }
}
