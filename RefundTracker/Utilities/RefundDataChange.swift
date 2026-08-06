import Foundation

extension Notification.Name {
    /// SwiftData queries normally merge context changes automatically. A
    /// deletion can keep a now-invalid navigation destination alive, though,
    /// so collection roots use this signal to rebuild their query wrappers.
    static let refundDataDidChange = Notification.Name(
        "com.justinyan.RefundTracker.refundDataDidChange"
    )

    /// Allows an async reminder failure to be presented after a save sheet has
    /// already dismissed. The persisted refund is never rolled back.
    static let refundReminderSchedulingFailed = Notification.Name(
        "com.justinyan.RefundTracker.refundReminderSchedulingFailed"
    )
}
