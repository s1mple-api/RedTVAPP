import XCTest

final class NavigationTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testCompletedMatchShowsContinuousMapFlow() throws {
        let app = XCUIApplication()
        app.launch()
        app.open(URL(string: "redtv://wanmei/matches/2399855")!)
        XCTAssertTrue(app.navigationBars["比赛详情"].waitForExistence(timeout: 10))
        let heading = app.descendants(matching: .any).matching(identifier: "match-veto-section").firstMatch
        guard heading.waitForExistence(timeout: 15) else {
            throw XCTSkip("完美世界历史比赛数据未能载入，无法验证真实地图统计交互。")
        }
        revealMatchSection(app, identifier: "match-veto-section", maxSwipes: 6)
        save(app, name: "已结束比赛 · BP 选禁流程")
        revealMatchSection(app, identifier: "match-results-section", maxSwipes: 12)
        revealMatchSection(app, identifier: "match-stats-map-all", maxSwipes: 4)
        let allMaps = app.buttons["match-stats-map-all"]
        XCTAssertTrue(allMaps.isSelected)
        assertStatsScope(app, identifier: "match-stats-players", scope: "all")
        save(app, name: "赛后数据 · 全部地图选手统计")

        let map = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "match-stats-map-", "match-stats-map-all")).firstMatch
        XCTAssertTrue(map.exists, "已结束比赛应提供单图筛选")
        let mapID = String(map.identifier.dropFirst("match-stats-map-".count))
        map.tap()
        XCTAssertTrue(map.isSelected)
        XCTAssertFalse(allMaps.isSelected)
        assertStatsScope(app, identifier: "match-stats-players", scope: mapID)
        save(app, name: "赛后数据 · 单张地图选手统计")

        revealMatchSection(app, identifier: "match-stats-mode", maxSwipes: 4)
        let mode = app.segmentedControls["match-stats-mode"]
        mode.buttons["对位数据"].tap()
        XCTAssertTrue(mode.buttons["对位数据"].isSelected)
        XCTAssertTrue(map.isSelected, "切换数据类型应保留所选地图")
        assertStatsScope(app, identifier: "match-stats-duels", scope: mapID)
        XCTAssertTrue(app.scrollViews["match-duel-matrix"].waitForExistence(timeout: 5), "应展示该地图的真实选手对位矩阵")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "match-stats-players").firstMatch.exists)
        save(app, name: "赛后数据 · 单图选手击杀对位")

        allMaps.tap()
        XCTAssertTrue(allMaps.isSelected)
        XCTAssertTrue(mode.buttons["对位数据"].isSelected, "切换地图应保留对位展示模式")
        assertStatsScope(app, identifier: "match-stats-duels", scope: "all")
        XCTAssertTrue(app.scrollViews["match-duel-matrix"].exists, "应展示全部地图的真实选手对位矩阵")
        save(app, name: "赛后数据 · 全部地图击杀对位")
        mode.buttons["选手数据"].tap()
        assertStatsScope(app, identifier: "match-stats-players", scope: "all")
        revealMatchSection(app, identifier: "match-analysis-section", maxSwipes: 12)
        save(app, name: "已结束比赛 · 两队地图分析")
    }
    private func assertStatsScope(_ app: XCUIApplication, identifier: String, scope: String, file: StaticString = #filePath, line: UInt = #line) {
        let content = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 5), "Missing post-match data: \(identifier)", file: file, line: line)
        let matched = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", scope), object: content)
        XCTAssertEqual(XCTWaiter.wait(for: [matched], timeout: 5), .completed, "Unexpected map scope in \(identifier)", file: file, line: line)
    }
    func testArenaTabsSettingsAndAccountValidation() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["赛场"].waitForExistence(timeout: 10))
        assertHeader(app, key: "arena", title: "赛场")
        app.buttons["header-search-arena"].tap()
        XCTAssertTrue(app.navigationBars["搜索"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        assertHeader(app, key: "arena", title: "赛场")
        XCTAssertTrue(app.staticTexts["每一局，都值得关注。"].exists)
        XCTAssertFalse(app.tabBars.buttons["社区"].exists)
        let focus = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "featured-match-")).firstMatch
        if focus.waitForExistence(timeout: 15) {
            let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "featured-match-"))
            XCTAssertLessThanOrEqual(cards.count, 3)
            save(app, name: "今日焦点与左右赛程")
            let position = app.staticTexts["featured-page-position"]
            let count = (position.value as? String)?.split(separator: "/").last.flatMap { Int($0) } ?? 1
            XCTAssertLessThanOrEqual(count, 3)
            if count > 1 {
                let deck = app.descendants(matching: .any).matching(identifier: "featured-matches-deck").firstMatch
                if deck.exists {
                    deck.swipeLeft()
                    expectation(for: NSPredicate(format: "value == %@", "2/\(count)"), evaluatedWith: position)
                    waitForExpectations(timeout: 5)
                }
            }
            (cards.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? focus).tap()
            XCTAssertTrue(app.navigationBars["比赛详情"].waitForExistence(timeout: 5))
            let veto = app.descendants(matching: .any).matching(identifier: "match-veto-section").firstMatch
            _ = veto.waitForExistence(timeout: 15)
            XCTAssertFalse(app.segmentedControls.buttons["赛况 / BP"].exists)
            XCTAssertFalse(app.segmentedControls.buttons["赛后数据"].exists)
            XCTAssertFalse(app.segmentedControls.buttons["地图分析"].exists)
            revealMatchSection(app, identifier: "match-veto-section", maxSwipes: 6)
            save(app, name: "比赛详情 · 地图 BP 连续流程")
            revealMatchSection(app, identifier: "match-results-section", maxSwipes: 12)
            save(app, name: "比赛详情 · 已完成地图连续统计")
            revealMatchSection(app, identifier: "match-analysis-section", maxSwipes: 12)
            save(app, name: "比赛详情 · 地图分析")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        save(app, name: "统一头部 · 赛场")
        app.tabBars.buttons["赛事"].tap()
        assertHeader(app, key: "events", title: "赛事")
        XCTAssertTrue(app.segmentedControls.buttons["已结束"].waitForExistence(timeout: 5))
        save(app, name: "统一头部 · 赛事")
        app.segmentedControls.buttons["已结束"].tap()
        app.tabBars.buttons["数据"].tap()
        assertHeader(app, key: "data", title: "数据")
        XCTAssertTrue(app.segmentedControls.buttons["选手数据"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["HLTV"].exists)
        app.segmentedControls.buttons["Valve"].tap()
        XCTAssertTrue(app.staticTexts["Valve VRS 战队排名"].exists)
        app.segmentedControls.buttons["HLTV"].tap()
        XCTAssertTrue(app.staticTexts["HLTV 战队排名"].exists)
        _ = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Spirit")).firstMatch.waitForExistence(timeout: 12)
        save(app, name: "统一头部 · 数据与 HLTV 排名")
        let roster = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "roster-player-")).firstMatch
        if roster.waitForExistence(timeout: 10), roster.isHittable {
            roster.tap()
            XCTAssertTrue(app.navigationBars["选手"].waitForExistence(timeout: 5))
            if app.segmentedControls.buttons["基础信息"].waitForExistence(timeout: 12) {
                XCTAssertTrue(app.staticTexts["八维概览"].exists)
                save(app, name: "选手详情 · 八维概览")
                app.segmentedControls.buttons["比赛赛程"].tap()
                XCTAssertTrue(app.staticTexts["即将开始"].exists)
                app.segmentedControls.buttons["历史荣誉"].tap()
                save(app, name: "选手详情 · 历史荣誉")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.segmentedControls.buttons["选手数据"].tap()
        XCTAssertTrue(app.staticTexts["Impact"].exists)
        save(app, name: "选手数据")
        app.tabBars.buttons["新闻"].tap()
        assertHeader(app, key: "news", title: "新闻")
        XCTAssertTrue(app.staticTexts["赛场之外，看见世界。"].waitForExistence(timeout: 5))
        save(app, name: "统一头部 · 新闻")
        app.tabBars.buttons["我的"].tap()
        assertHeader(app, key: "profile", title: "我的")
        save(app, name: "统一头部 · 我的")
        app.buttons["arena-follows"].tap()
        XCTAssertTrue(app.navigationBars["赛事关注"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["header-settings-profile"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        app.buttons["appearance-dark"].tap()
        save(app, name: "深色主题设置")
        app.buttons["appearance-light"].tap()
        save(app, name: "浅色主题设置")
        app.buttons["appearance-system"].tap()
        app.buttons["appearance-light"].tap()
        app.buttons["连接设置"].tap()
        XCTAssertTrue(app.textFields["settings-api-url"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "让热爱")).firstMatch.tap()
        XCTAssertTrue(app.textFields["auth-username"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["auth-submit"].isEnabled)
    }
    private func revealMatchSection(_ app: XCUIApplication, identifier: String, maxSwipes: Int, file: StaticString = #filePath, line: UInt = #line) {
        let heading = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "Missing match detail scroll view", file: file, line: line)
        for _ in 0..<maxSwipes {
            if heading.exists && heading.isHittable { return }
            // Drag upward through the content, away from the navigation bar and
            // bottom tab bar. Never pull down into the refresh gesture.
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.78))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.30))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(heading.exists && heading.isHittable, "Match section was not visible after scrolling: \(identifier)", file: file, line: line)
    }
    private func assertHeader(_ app: XCUIApplication, key: String, title: String, file: StaticString = #filePath, line: UInt = #line) {
        let header = app.descendants(matching: .any).matching(identifier: "page-header-\(key)").firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Missing shared header for \(key)", file: file, line: line)
        XCTAssertTrue(app.staticTexts[title].firstMatch.exists, "Missing page title for \(key)", file: file, line: line)
        XCTAssertTrue(app.buttons["header-search-\(key)"].exists, "Missing search action for \(key)", file: file, line: line)
        XCTAssertTrue(app.buttons["header-settings-\(key)"].exists, "Missing settings action for \(key)", file: file, line: line)
    }
    private func save(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
