import Testing
@testable import Syllabus_Sync

struct AuthErrorHandlerTests {
    @Test(arguments: [
        "email rate limit exceeded",
        "429: Email rate limit exceeded",
        "over_email_send_rate_limit"
    ])
    func emailQuotaIsNotBlamedOnUserAttempts(_ message: String) {
        let error = AuthErrorHandler.mapError(message)
        guard case .emailSendLimitExceeded = error else {
            Issue.record("Expected project email quota error for: \(message)")
            return
        }
        #expect(error.localizedDescription.contains("email sending limit"))
    }

    @Test(arguments: [
        "too many requests",
        "over_request_rate_limit",
        "For security purposes, you can only request this after 60 seconds."
    ])
    func requestThrottlingRemainsSeparate(_ message: String) {
        guard case .rateLimitExceeded = AuthErrorHandler.mapError(message) else {
            Issue.record("Expected request throttle for: \(message)")
            return
        }
    }

    @Test(arguments: [
        "Database error creating recovery token: ERROR: column expires_at does not exist",
        "unexpected_failure"
    ])
    func databaseFailuresDoNotExposeInternalDetails(_ message: String) {
        let error = AuthErrorHandler.mapError(message)
        guard case .serviceUnavailable = error else {
            Issue.record("Expected service unavailable for: \(message)")
            return
        }
        #expect(!error.localizedDescription.contains("expires_at"))
    }

    @Test func invalidCredentialsKeepTheirExistingMeaning() {
        guard case .invalidCredentials = AuthErrorHandler.mapError("Invalid login credentials") else {
            Issue.record("Invalid credentials must remain distinct from service failures")
            return
        }
    }
}
