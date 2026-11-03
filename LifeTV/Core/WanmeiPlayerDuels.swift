import Foundation

struct ArenaDuelScore {
    let leftKills: Int
    let rightKills: Int
}

/// The public match response stores columns in team1List and rows in team2List.
/// Each scoreList pair is [row kills, column kills]. These source groups can
/// reverse between maps, so resolve their orientation against the map rosters.
/// Verified against getMatchDetail(2399855) and the public MatchLaneData web
/// component at https://data.wanmei.com/csgo on 2026-11-03.
struct ArenaPlayerDuels {
    let statsID: String
    let left: [ArenaPlayer]
    let right: [ArenaPlayer]
    private let scores: [String: ArenaDuelScore]

    func score(leftID: Int, rightID: Int) -> ArenaDuelScore? {
        scores["\(leftID):\(rightID)"]
    }

    init?(_ raw: ArenaJSON, map: ArenaFullMapStats, team1: ArenaTeam, team2: ArenaTeam) {
        func player(_ value: ArenaJSON) -> ArenaPlayer {
            guard case var .object(fields) = value else { return ArenaPlayer(.null) }
            fields["image"] = .string(value.firstText("img", "image"))
            return ArenaPlayer(.object(fields))
        }
        let columnValues = raw["team1List"].array
        let rowValues = raw["team2List"].array
        let columns = columnValues.map(player)
        let rows = rowValues.map(player)
        let columnIDs = Set(columns.map(\.id)), rowIDs = Set(rows.map(\.id))
        guard !columns.isEmpty, !rows.isEmpty,
              columns.allSatisfy({ $0.id > 0 }), rows.allSatisfy({ $0.id > 0 }),
              columnIDs.count == columns.count, rowIDs.count == rows.count,
              columnIDs.isDisjoint(with: rowIDs) else { return nil }

        // Historical match rosters take precedence over current team rosters.
        let leftRoster = Set(map.left.isEmpty ? team1.players.map(\.id) : map.left.map(\.id))
        let rightRoster = Set(map.right.isEmpty ? team2.players.map(\.id) : map.right.map(\.id))
        let direct = columnIDs.isDisjoint(with: rightRoster) && rowIDs.isDisjoint(with: leftRoster)
        let reversed = columnIDs.isDisjoint(with: leftRoster) && rowIDs.isDisjoint(with: rightRoster)
        // Neither a conflicting orientation nor an entirely unknown roster is safe.
        guard direct != reversed else { return nil }

        func count(_ value: ArenaJSON) -> Int? {
            guard let number = value.number, number.isFinite, number >= 0,
                  number.rounded(.towardZero) == number else { return nil }
            return value.int
        }
        var parsed: [String: ArenaDuelScore] = [:]
        for (rowIndex, row) in rows.enumerated() {
            let values = rowValues[rowIndex]["scoreList"].array
            for (columnIndex, column) in columns.enumerated() {
                let offset = columnIndex * 2
                guard values.count > offset + 1,
                      let rowKills = count(values[offset]), let columnKills = count(values[offset + 1]) else { continue }
                let leftID = direct ? column.id : row.id
                let rightID = direct ? row.id : column.id
                parsed["\(leftID):\(rightID)"] = ArenaDuelScore(leftKills: direct ? columnKills : rowKills, rightKills: direct ? rowKills : columnKills)
            }
        }
        guard !parsed.isEmpty else { return nil }
        statsID = raw["statsId"].text
        left = direct ? columns : rows
        right = direct ? rows : columns
        scores = parsed
    }
}
