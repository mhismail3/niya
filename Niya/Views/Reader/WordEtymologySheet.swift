import SwiftUI

struct WordEtymologySheet: View {
    let surahId: Int
    let ayahId: Int
    let word: QuranWord
    @Environment(MorphologyService.self) private var morphologyService
    @Environment(QuranDataService.self) private var dataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Word Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        let morph = morphologyService.morphology(surahId: surahId, ayahId: ayahId, position: word.p)
        if let morph {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection(morph)
                    rootAndLemmaRow(morph)
                    meaningsSection(morph)
                    grammarSection(morph)
                    frequencySection(morph)
                    relatedVersesSection(morph)
                }
                .padding()
            }
        } else {
            ContentUnavailableView {
                Label("No Details Available", systemImage: "character.book.closed")
            } description: {
                Text("Morphology data is not available for this word.")
            }
        }
    }

    private func headerSection(_ morph: WordMorphology) -> some View {
        VStack(spacing: 8) {
            Text(word.t)
                .font(.custom(QuranScript.hafs.fontName, size: 36))
                .foregroundStyle(Color.niyaText)

            if !word.tr.isEmpty {
                Text(word.tr)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)
            }

            Text(word.displayMeaning)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(Color.niyaSecondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func rootAndLemmaRow(_ morph: WordMorphology) -> some View {
        if let root = morph.root {
            HStack(spacing: 12) {
                rootCard(root)
                if let lemma = morph.lemma {
                    lemmaCard(lemma)
                }
            }
        } else if let lemma = morph.lemma {
            HStack(spacing: 12) {
                particleMessage
                lemmaCard(lemma)
            }
        } else {
            particleMessage
        }
    }

    private func rootCard(_ root: String) -> some View {
        VStack(spacing: 6) {
            Text("Root")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)

            Text(root)
                .font(.custom("NotoNaskhArabic", size: 24))
                .foregroundStyle(Color.niyaText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.niyaTeal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func lemmaCard(_ lemma: String) -> some View {
        VStack(spacing: 6) {
            Text("Lemma")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)

            Text(lemma)
                .font(.custom("NotoNaskhArabic", size: 24))
                .foregroundStyle(Color.niyaText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.niyaTeal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var particleMessage: some View {
        Text("This word is a particle (حرف) and has no root.")
            .font(.niyaSubheadline)
            .foregroundStyle(Color.niyaSecondary)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func meaningsSection(_ morph: WordMorphology) -> some View {
        if let root = morph.root, let meanings = morphologyService.rootMeanings(root), !meanings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Possible Meanings", arabic: "المعاني المحتملة")

                VStack(spacing: 0) {
                    ForEach(Array(meanings.enumerated()), id: \.offset) { _, meaning in
                        HStack(alignment: .center) {
                            Text(meaning.pos)
                                .font(.niyaCaption)
                                .foregroundStyle(Color.niyaTeal)
                                .frame(width: 90, alignment: .leading)

                            Text(meaning.def)
                                .font(.niyaSubheadline)
                                .foregroundStyle(Color.niyaText)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
                .background(Color.niyaSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func grammarSection(_ morph: WordMorphology) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Grammar", arabic: "الإعراب")

            VStack(spacing: 0) {
                grammarRow(label: "Part of Speech", arabic: "نوع الكلمة", value: MorphLabel.pos(morph.pos))

                if let f = morph.features {
                    if let cas = f.cas { grammarRow(label: "Case", arabic: "الحالة", value: MorphLabel.cas(cas)) }
                    if let mood = f.mood { grammarRow(label: "Mood", arabic: "الإعراب", value: MorphLabel.mood(mood)) }
                    if let gen = f.gen { grammarRow(label: "Gender", arabic: "الجنس", value: MorphLabel.gender(gen)) }
                    if let num = f.num { grammarRow(label: "Number", arabic: "العدد", value: MorphLabel.number(num)) }
                    if let per = f.per { grammarRow(label: "Person", arabic: "الشخص", value: MorphLabel.person(per)) }
                    if let voice = f.voice { grammarRow(label: "Voice", arabic: "البناء", value: MorphLabel.voice(voice)) }
                    if let aspect = f.aspect { grammarRow(label: "Aspect", arabic: "الزمن", value: MorphLabel.aspect(aspect)) }
                    if let form = f.form { grammarRow(label: "Verb Form", arabic: "باب الفعل", value: MorphLabel.verbForm(form)) }
                }
            }
            .background(Color.niyaSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func grammarRow(label: String, arabic: String, value: (en: String, ar: String)?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.niyaSubheadline)
                    .foregroundStyle(Color.niyaText)
                Text(arabic)
                    .font(.custom("NotoNaskhArabic", size: 12))
                    .foregroundStyle(Color.niyaSecondary)
            }
            Spacer()
            if let value {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value.en)
                        .font(.niyaSubheadline)
                        .foregroundStyle(Color.niyaTeal)
                    Text(value.ar)
                        .font(.custom("NotoNaskhArabic", size: 12))
                        .foregroundStyle(Color.niyaSecondary)
                }
            } else {
                Text("—")
                    .foregroundStyle(Color.niyaSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func frequencySection(_ morph: WordMorphology) -> some View {
        if let root = morph.root, let entry = morphologyService.rootEntry(root) {
            VStack(alignment: .leading, spacing: 4) {
                sectionHeader("Frequency", arabic: "التكرار")
                HStack(spacing: 4) {
                    Text("This root appears")
                        .font(.niyaSubheadline)
                        .foregroundStyle(Color.niyaSecondary)
                    Text("\(entry.freq)")
                        .font(.niyaSubheadline)
                        .foregroundStyle(Color.niyaTeal)
                    Text("times in the Quran")
                        .font(.niyaSubheadline)
                        .foregroundStyle(Color.niyaSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func relatedVersesSection(_ morph: WordMorphology) -> some View {
        if let root = morph.root, let entry = morphologyService.rootEntry(root), !entry.refs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Other Verses with This Root", arabic: "آيات أخرى بنفس الجذر")

                let grouped = groupedRefs(entry.refs)
                ForEach(grouped, id: \.surahId) { group in
                    HStack(alignment: .top) {
                        Text(group.name)
                            .font(.niyaSubheadline)
                            .foregroundStyle(Color.niyaText)
                            .frame(width: 110, alignment: .leading)

                        FlowLayout(spacing: 6) {
                            ForEach(group.ayahs, id: \.self) { ayahId in
                                Button {
                                    coordinator.navigateToAyah(surahId: group.surahId, ayahId: ayahId)
                                    dismiss()
                                } label: {
                                    Text("\(ayahId)")
                                        .font(.niyaCaption)
                                        .foregroundStyle(Color.niyaTeal)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.niyaTeal.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private struct SurahRefGroup {
        let surahId: Int
        let name: String
        let ayahs: [Int]
    }

    private func groupedRefs(_ refs: [MorphRef]) -> [SurahRefGroup] {
        var order: [Int] = []
        var map: [Int: [Int]] = [:]
        for ref in refs {
            if map[ref.s] == nil {
                order.append(ref.s)
                map[ref.s] = []
            }
            map[ref.s]!.append(ref.v)
        }
        return order.map { sid in
            let name = dataService.surahs.first(where: { $0.id == sid })?.transliteration ?? "Surah \(sid)"
            let ayahs = map[sid]!.sorted()
            return SurahRefGroup(surahId: sid, name: name, ayahs: ayahs)
        }
    }

    private func sectionHeader(_ title: String, arabic: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.niyaHeadline)
                .foregroundStyle(Color.niyaText)
            Text(arabic)
                .font(.custom("NotoNaskhArabic", size: 14))
                .foregroundStyle(Color.niyaSecondary)
            Spacer()
        }
    }
}
