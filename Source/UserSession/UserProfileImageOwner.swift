//

import Foundation
import WireImages

public final class UserProfileImageOwner: NSObject, ZMImageOwner {
    
    static var imageFormats: [ZMImageFormat] {
        return [.medium, .profile]
    }
    
    let imageData: Data
    var processedImages = [ZMImageFormat : Data]()
    
    init(imageData: Data) {
        self.imageData = imageData
        super.init()
    }
    
    public func setImageData(_ imageData: Data, for format: ZMImageFormat, properties: ZMIImageProperties?) {
        processedImages[format] = imageData
    }
    
    public func imageData(for format: ZMImageFormat) -> Data? {
        return processedImages[format]
    }
    
    public func requiredImageFormats() -> NSOrderedSet {
        return NSOrderedSet(array: UserProfileImageOwner.imageFormats.map { $0.rawValue })
    }
    
    public func originalImageData() -> Data? {
        return imageData
    }
    
    public func originalImageSize() -> CGSize {
        return .zero
    }
    
    public func isInline(for format: ZMImageFormat) -> Bool {
        return false
    }
    
    public func isPublic(for format: ZMImageFormat) -> Bool {
        return false
    }
    
    public func isUsingNativePush(for format: ZMImageFormat) -> Bool {
        return false
    }
    
    public func processingDidFinish() {
        
    }

}

