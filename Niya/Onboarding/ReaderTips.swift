import TipKit

struct BookmarkToolbarTip: Tip {
    var title: Text { Text("Bookmarks") }
    var message: Text? { Text("View and manage your saved verses") }
    var image: Image? { Image(systemName: "bookmark") }
}

struct FollowAlongToolbarTip: Tip {
    @Parameter
    static var bookmarkDismissed: Bool = false

    var title: Text { Text("Follow Along") }
    var message: Text? { Text("Highlight each word as it's recited") }
    var image: Image? { Image(systemName: "text.word.spacing") }

    var rules: [Rule] {
        #Rule(Self.$bookmarkDismissed) { $0 }
    }
}

struct SettingsToolbarTip: Tip {
    @Parameter
    static var followAlongDismissed: Bool = false

    var title: Text { Text("Settings") }
    var message: Text? { Text("Customize font size, script, and reciter") }
    var image: Image? { Image(systemName: "gearshape") }

    var rules: [Rule] {
        #Rule(Self.$followAlongDismissed) { $0 }
    }
}

struct PlayVerseTip: Tip {
    @Parameter
    static var settingsDismissed: Bool = false

    var title: Text { Text("Play") }
    var message: Text? { Text("Listen to this verse recited aloud") }
    var image: Image? { Image(systemName: "play.circle") }

    var rules: [Rule] {
        #Rule(Self.$settingsDismissed) { $0 }
    }
}

struct BookmarkVerseTip: Tip {
    @Parameter
    static var playDismissed: Bool = false

    var title: Text { Text("Bookmark") }
    var message: Text? { Text("Save this verse for quick access") }
    var image: Image? { Image(systemName: "bookmark") }

    var rules: [Rule] {
        #Rule(Self.$playDismissed) { $0 }
    }
}

struct TafsirVerseTip: Tip {
    @Parameter
    static var bookmarkVerseDismissed: Bool = false

    var title: Text { Text("Tafsir") }
    var message: Text? { Text("Read scholarly commentary on this verse") }
    var image: Image? { Image(systemName: "text.book.closed") }

    var rules: [Rule] {
        #Rule(Self.$bookmarkVerseDismissed) { $0 }
    }
}
