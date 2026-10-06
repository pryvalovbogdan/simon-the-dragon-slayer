import Foundation

/// What the end screen awards. Raw values are the animation names of the `medal` sprite.
public enum Medal: String, Sendable, CaseIterable {
    case bronze, silver, gold

    /// An endless run earns bronze for a first level, silver for a full loop and gold for two.
    public static func forEndless(cleared: Int, levelCount: Int) -> Medal? {
        let loop = max(levelCount, 1)
        if cleared >= loop * 2 { return .gold }
        if cleared >= loop { return .silver }
        return cleared >= 1 ? .bronze : nil
    }

    /// A level won on its own is judged by the hearts left: all of them for gold, one lost for silver.
    public static func forLevel(won: Bool, hearts: Int, maxHearts: Int) -> Medal? {
        guard won else { return nil }
        if hearts >= maxHearts { return .gold }
        return hearts == maxHearts - 1 ? .silver : .bronze
    }
}
