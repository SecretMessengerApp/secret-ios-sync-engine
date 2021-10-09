//

import WireSyncEngine

class MockCompanyLoginRequesterDelegate: CompanyLoginRequesterDelegate {

    private let verificationBlock: (URL) -> Void

    init(verificationBlock: @escaping (URL) -> Void) {
        self.verificationBlock = verificationBlock
    }

    func companyLoginRequester(_ requester: CompanyLoginRequester, didRequestIdentityValidationAtURL url: URL) {
        verificationBlock(url)
    }

}
