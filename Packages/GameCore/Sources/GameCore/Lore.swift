import Foundation

/// Every name and piece of display text in the game (Lore.json), keyed by neutral ids such as
/// `hero.name` or `boss_dragon.name`. Code and asset names use the ids, never the display names,
/// so renaming something is a one-line change in the JSON.
public struct Lore: Sendable, Equatable {
    public var strings: [String: String]

    public init(strings: [String: String]) {
        self.strings = strings
    }

    public init(data: Data) throws {
        strings = try JSONDecoder().decode([String: String].self, from: data)
    }

    /// The text for `key`, or the key itself if it is missing (so a gap is visible on screen).
    public func text(_ key: String) -> String {
        strings[key] ?? key
    }
}
