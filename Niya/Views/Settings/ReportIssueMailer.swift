import MessageUI
import SwiftUI

enum DeviceInfo {
    static func summary() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let ios = ProcessInfo.processInfo.operatingSystemVersionString

        var sysInfo = utsname()
        uname(&sysInfo)
        let device = withUnsafePointer(to: &sysInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }

        let locale = Locale.current.identifier
        let defaults = UserDefaults.standard
        let script = defaults.string(forKey: StorageKey.selectedScript) ?? "hafs"
        let reciter = defaults.string(forKey: StorageKey.selectedReciter) ?? "alAfasy"
        let readerMode = defaults.string(forKey: StorageKey.readerMode) ?? "scroll"
        let tajweed = defaults.bool(forKey: StorageKey.showTajweed) ? "On" : "Off"
        let supplementalTajweed = defaults.bool(forKey: StorageKey.showSupplementalTajweedRules) ? "On" : "Off"
        let followAlong = defaults.bool(forKey: StorageKey.followAlong) ? "On" : "Off"

        return """
        --- Device Info ---
        App: \(version) (\(build))
        iOS: \(ios)
        Device: \(device)
        Locale: \(locale)
        Script: \(script)
        Reciter: \(reciter)
        Reader: \(readerMode)
        Tajweed: \(tajweed)
        Supplemental Tajweed: \(supplementalTajweed)
        Follow Along: \(followAlong)
        """
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    static let recipient = "niya@mhismail.com"

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([Self.recipient])
        vc.setSubject("Niya — Issue Report")
        vc.setMessageBody(
            """
            [Describe the issue here]




            \(DeviceInfo.summary())
            """,
            isHTML: false
        )
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        init(_ parent: MailComposeView) { self.parent = parent }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isPresented = false
        }
    }
}
