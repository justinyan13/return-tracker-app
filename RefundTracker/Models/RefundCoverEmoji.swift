import Foundation

/// The emoji a return can wear on its tile, grouped the way someone would
/// think about what they sent back rather than by Unicode category.
enum RefundCoverEmoji {
    struct Group: Identifiable {
        let name: String
        let emoji: [String]

        var id: String { name }
    }

    static let groups: [Group] = [
        Group(
            name: "Wardrobe",
            emoji: [
                "👗", "👚", "👕", "👖", "🧥", "🩳", "👘",
                "🥻", "🩱", "👙", "🧦", "🦺"
            ]
        ),
        Group(
            name: "Shoes & bags",
            emoji: [
                "👠", "👡", "👢", "👟", "🥿", "🩰", "👜",
                "👛", "👝", "🎒", "🧳", "💼"
            ]
        ),
        Group(
            name: "Accessories",
            emoji: [
                "💍", "📿", "👑", "🕶️", "👓", "🧢", "👒",
                "🎩", "🧣", "🧤", "⌚️", "💎"
            ]
        ),
        Group(
            name: "Beauty",
            emoji: [
                "💄", "💅", "🧴", "🧼", "🪮", "🪞", "🧖", "🌸"
            ]
        ),
        Group(
            name: "Home",
            emoji: [
                "🕯️", "🛋️", "🪴", "🖼️", "🍽️", "☕️", "🫖",
                "🧺", "🛏️", "🪑", "🧸", "🪟"
            ]
        ),
        Group(
            name: "Tech & media",
            emoji: [
                "🎧", "📱", "💻", "⌨️", "📷", "🎮", "📚", "🎬"
            ]
        ),
        Group(
            name: "Everyday",
            emoji: [
                "📦", "🛍️", "🎁", "✨", "🌿", "🍷", "🐚",
                "🌙", "⭐️", "❤️", "🔮", "🧿"
            ]
        )
    ]

    static let all: [String] = groups.flatMap(\.emoji)

    /// A fresh return picks one at random, so a new tile has some character
    /// before the user has decided anything.
    static func random(excluding current: String? = nil) -> String {
        let choices = all.filter { $0 != current }
        return choices.randomElement() ?? all.first ?? "📦"
    }

    /// The stand-in for returns saved before covers existed, and for any left
    /// blank. Derived from the merchant name rather than chosen at random so a
    /// tile does not change every time the row is drawn — `hashValue` is seeded
    /// per process and would do exactly that.
    static func derived(for merchantName: String) -> String {
        guard !all.isEmpty else { return "📦" }
        let fold = merchantName.unicodeScalars.reduce(0) {
            (($0 &* 31) &+ Int($1.value)) & 0x7fff_ffff
        }
        return all[fold % all.count]
    }
}
