struct TajweedVerse: Codable, Identifiable {
    let id: Int
    let text: String
    let annotations: [TajweedAnnotation]
}
