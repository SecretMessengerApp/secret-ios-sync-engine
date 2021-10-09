//

import Foundation

extension LinkPreviewAssetUploadRequestStrategy {

    @objc(createWithManagedObjectContext:applicationStatus:)
    public static func create(withManagedObjectContext managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus) -> LinkPreviewAssetUploadRequestStrategy {
        return LinkPreviewAssetUploadRequestStrategy(managedObjectContext: managedObjectContext, applicationStatus: applicationStatus, linkPreviewPreprocessor: nil, previewImagePreprocessor: nil)
    }

}
