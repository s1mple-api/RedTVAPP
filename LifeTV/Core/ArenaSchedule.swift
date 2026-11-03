import Foundation

enum ArenaSchedule {
    static func prioritized(_ matches: [ArenaMatch]) -> [ArenaMatch] {
        matches.sorted {
            if $0.stars != $1.stars { return $0.stars > $1.stars }
            if $0.status != $1.status { return order($0.status) < order($1.status) }
            if $0.start != $1.start { return $0.status == 3 ? ($0.start ?? .distantPast) > ($1.start ?? .distantPast) : ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
            return $0.id < $1.id
        }
    }
    static func highlights(_ matches: [ArenaMatch]) -> [ArenaMatch] {
        let active = matches.filter { $0.status == 1 || $0.status == 2 }
        let rated = active.filter { $0.stars > 0 }
        let pool = !rated.isEmpty ? rated : !active.isEmpty ? active : matches
        var seen = Set<Int>()
        return Array(prioritized(pool).filter { seen.insert($0.id).inserted }.prefix(3))
    }
    private static func order(_ status: Int) -> Int { switch status { case 1: 0; case 2: 1; case 3: 2; default: 3 } }
}
