import Testing
import UserNotifications
@testable import Niya

@Suite("AppUpdateReminderScheduler")
struct AppUpdateReminderSchedulerTests {
    @Test func defaultEnabledBuildsSingleRepeatingRequest() throws {
        let requests = AppUpdateReminderScheduler.buildRequests()

        #expect(requests.count == 1)
        #expect(requests.first?.identifier == AppUpdateReminderScheduler.identifier)

        let trigger = try #require(requests.first?.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == AppUpdateReminderScheduler.reminderInterval)
        #expect(trigger.repeats)
    }

    @Test func disabledBuildsNoRequest() {
        let requests = AppUpdateReminderScheduler.buildRequests(enabled: false)

        #expect(requests.isEmpty)
    }

    @Test func contentHasExpectedFields() throws {
        let request = try #require(AppUpdateReminderScheduler.buildRequests().first)

        #expect(request.content.title == "Check for Niya Updates")
        #expect(request.content.body == "Open the App Store to make sure you have the latest version.")
        #expect(request.content.sound == .default)
        #expect(request.content.categoryIdentifier == "appUpdateReminder")
        #expect(request.content.userInfo["destination"] as? String == "appStore")
    }

    @Test func reminderIntervalIsExactlyTwoWeeks() {
        #expect(AppUpdateReminderScheduler.reminderInterval == 14 * 24 * 60 * 60)
    }

    @Test func appStoreURLUsesPublishedNiyaListing() {
        #expect(AppUpdateReminderScheduler.appStoreURL.absoluteString == "https://apps.apple.com/us/app/niya-make-your-intention/id6759700883")
    }

    @Test func defaultsToEnabledWhenPreferenceIsMissing() {
        let suiteName = "com.niya.mobile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        #expect(AppUpdateReminderScheduler.isEnabled(userDefaults: defaults))
    }

    @Test func storedPreferenceOverridesDefault() {
        let suiteName = "com.niya.mobile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(false, forKey: StorageKey.appUpdateRemindersEnabled)

        #expect(!AppUpdateReminderScheduler.isEnabled(userDefaults: defaults))
    }
}
