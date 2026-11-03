# Red TV iOS · CS2 Match Center

Swift / SwiftUI 原生 iOS App，最低 iOS 17，无第三方依赖。围绕完美世界电竞的公开 CS2 赛事数据设计，BBC 国际新闻为辅助栏目。

## 用 Xcode 运行

1. 打开 **RedTV.xcodeproj**，不要单独运行 RedTVApp.swift。安装后的 App 显示名称为 **Red TV**。
2. 顶部选择 **RedTV Run** 和一个已安装的 iPhone 模拟器，按 **⌘R**。
3. RedTV Run 使用 Debug 构建，不附加 LLDB。需要断点调试时选择 RedTV；本机此前出现过 LLDB RPC Server 退出或启动挂起。
4. 模拟器无需证书。真机运行需要在 Signing & Capabilities 选择自己的 Development Team，并按需调整 Bundle Identifier。

`.xcodeproj` 是 Xcode 工程包，记录构建目标、设置、资源和测试。此工程使用同步文件夹，RedTV 目录中的 Swift 文件自动参与 App 构建；单文件运行不会加载整个工程。无需重新新建工程。

## 原生信息结构

| 页面 | 内容 |
| --- | --- |
| 赛场 | 最多 3 场手动滑动的焦点叠卡、左侧日期 / 右侧对阵、有星级 / 无星级分组、状态与关注筛选 |
| 赛事 | 当前 / 历史赛事分页、赛期、奖金、地点、参赛战队和赛事赛程 |
| 数据 | HLTV / Valve 独立榜单与地区筛选、真实队标与选手定妆照、Impact 列表和生涯指标 |
| 新闻 | BBC 分类新闻、中文 / 来源原文、字号、关联阅读与原始报道链接 |
| 我的 | 本机赛事关注、新闻收藏与足迹、Red TV 账号、连接设置 |

赛场顶部优先选取今日有星级的进行中 / 待赛对局，按星级排序，最多叠放 3 场，只能手动滑动，不自动轮播；没有此类比赛时回退到其他当日对局。日期下的比赛分为“焦点对局”和“更多比赛”，有星级热度优先、星级从高到低；切换历史日期时顶部仍保留今日焦点。星级由完美世界提供，不代表观看人数，和本机个人关注独立。

比赛详情在比赛进行时订阅公开 WSS 当前地图回合比分，已结束则展示系列赛大局比分；WSS 无数据时明确标记为系列赛比分。比赛详情为单页连续滚动：地图 BP 按来源顺序展示带编号连线的选禁流程，接着展示赛后数据，最后展示两队地图场次、胜率和选禁倾向。赛后数据区域可筛选全部地图或某张已结束地图，再切换选手 K–D / ADR / Rating 与选手对位击杀矩阵，两项选择互相保留。全部地图使用来源总览，不自行平均 Rating；对位读取同一响应的 performanceStatsList，按 statsId 匹配，并按当场选手表校正两队方向。所有具体地图名称前统一展示本地地图徽标，覆盖 10 张主要地图，未知地图使用通用占位。完整单图统计使用 team1/2PlayerStatsDTOList，不能使用仅覆盖一方攻守半场的 CSiceDTOList。未开赛的来源 0:0 显示为待赛。没有统计时显示真实缺失状态。赛程列表通过下拉刷新更新；详情的实时小局比分随来源消息更新，退后台 / 离开页即取消订阅，不包含直播视频或推送通知。

已移除社区、贴吧、虎扑、小红书、热搜、讨论和管理员页面，以及这些栏目的请求。旧资料库链接仍保留，打开时可前往原网站查看。旧版 HLTV 数据库 ID 与完美世界 ID 使用不同路由，防止错误关联。

## 完美世界公开数据

入口：[完美世界电竞](https://data.wanmei.com/csgo)。原生客户端使用 URLSession 直接读取 `https://esports.wanmei.com/apg/eventcenter/csgo/` 下的公开 GET 接口；不使用账号 Cookie 或登录令牌。

`WanmeiSigner` 按网页公开 JavaScript 的规则生成签名（2026-11-02 对照 `csgo-e8e3d15b.js`）：

1. 参数值转字符串；数组按值排序。
2. 加入秒级 timestamp 与 16 字节安全随机 nonce（32 位小写十六进制）。
3. 参数名按 JavaScript UTF-16 顺序排序；UTF-8 表单编码，空格为 `+`，严格编码 `!'()*`。
4. 使用网页公开签名配置的 **UTF-8 文本**作为 HMAC-SHA256 key，输出小写十六进制。
5. 发送 `X-Timestamp`、`X-Nonce`、`X-Signature`，不把签名放在 URL 中。

公开配置来自网页发布资源，不是用户密钥。来源若更新签名配置或数据结构，需要同步更新客户端。

| 数据 | 接口（相对 csgo/） |
| --- | --- |
| 赛事列表 / 详情 | event/getEventList · event/getEventDetail |
| 每日 / 赛事赛程 | getMatchList · event/getMatchList |
| 比赛详情 / 地图分析 | getMatchDetail · getTeamAnalysis |
| 实时小局比分 | wss://wss-nami.wmpvp.com（仅当前比赛公开订阅） |
| HLTV / Valve 战队榜 | team/newRankList（searchType=0 / id） · team/rank（page / pageSize / type） |
| 战队详情 | team/detail |
| 选手列表 / 详情 | player/stats · player/stat/detail |
| 选手比赛 / 荣誉 | player/recentEventMatches · player/career |

每日赛程的 matchTime 必须为北京时间 `yyyy-MM-dd 00:00:00`。战队榜的 teamId 是 Nami ID，详情必须使用 hltvId。接口成功状态实际存在 code 0 和 1 两种。列表的 Impact、详情 Rating 3.0、战队 VRS 使用各自来源口径。赛事详情目前覆盖标准 eventType=1；其他赛事系统保留来源入口。单项赛事最多显示前 100 场比赛，完整赛程提供来源链接。

成功数据按完整接口与参数缓存最多 24 小时。连接失败时仅回退到真实成功缓存，并标注时间；不生成演示赛事。切换日期 / 筛选时清除上一个查询内容，避免过期响应覆盖当前页面。搜索覆盖启动时已同步的一页赛事、战队、选手和当前 BBC 新闻，非全站搜索。

`Scripts/wanmei_probe.py` 用 Python 标准库独立复核签名，执行少量公开 GET 请求。测试夹具是 2026-11-02 成功响应的裁剪副本，仅打包进测试目标，不作为 App 数据。

选手详情提供基础信息、即将开始 / 近期比赛与按 MVP / TOP20 / 冠军 / EVP 分类的历史荣誉。八轴概览使用来源的 7 项角色能力，以及 Rating 的 0–100 位置值；原始 Rating 3.0 单独显示，第 8 轴不是推算的官方职业能力。近期对阵优先使用 matchTime，避免将赛事起点 startTime 当成每场比赛时间。

## BBC 与账号

BBC 新闻及账号继续使用现有 Go 服务，默认 `https://redtv.icu`，可在「我的 → 连接设置」修改。只请求 world-news，不调用旧 dashboard 聚合社区数据。新闻缩略图采用固定尺寸，避免异步加载使文本错位；详情的“查看英文原文 / 显示中文”同时切换标题、摘要和正文，英文正文未同步时提供 BBC 来源文章入口。完美世界连接不受此设置影响。

- BBC 收藏 / 足迹按服务与账号隔离，支持匿名保存、登录合并和 tombstone 删除同步。
- 比赛 / 赛事 / 战队 / 选手关注独立保存在本机，不发送给旧 Go 资料库接口。
- 密码不保存。账号写入沿用 Cookie、Origin 与 X-Red-Request 的现有后端约定。
- Debug 允许 HTTP 本机联调；Release 仅接受 HTTPS。网站地址用于新闻分享与账号 Origin。
- 当前环境连接 redtv.icu 的 HTTPS 握手失败，因此 BBC 与真实账号同步尚未完成线上端到端验证。App 提供连接错误与重试。

支持 `redtv://wanmei/matches/2399855`、`redtv://wanmei/events/8245`、`redtv://article/123` 等自定义深链。普通 HTTPS 来源链接在系统浏览器打开；未配置 Universal Links。

## CS 风格品牌

默认浅色主题，以鲜红色（#FF2442）为主色。品牌名称为 Red TV，新标识以粗体 R 为主体，上部的电视窗口内嵌 CS 选手剪影，兼顾小尺寸辨识度与赛事风格；桌面图标为红底白色，浅色与深色启动图使用红色标识与 Red TV 字标。剪影来自 [Counter-Strike 官方公开 SVG](https://cdn.fastly.steamstatic.com/apps/csgo/images/csgo_react/global/logo_cs_sm.svg)，本地源文件与说明见 Branding/Source。

Red TV 品牌资源已通过 Debug / Release 构建及现有完整导航测试；两种构建产物的 CFBundleDisplayName 均为 Red TV。图标为 1024×1024 不透明 PNG，页头与启动标识保留矢量 PDF。Branding/Preview.png 和 Icon-Sizes.png 可查看浅深启动效果及 29 / 44 / 60 / 120pt 图标预览。

「我的 → 设置」可选择浅色、深色、跟随系统；选择自动保存在本机并即时作用于所有页面。队标按当前主题切换来源的浅色 / 深色图案。图片请求带网页使用的 Referer / Origin，避免 CDN 返回 403；选手列表缺少照片时读取对应公开资料中的定妆照，并复用缓存。

- AppIcon：1024 × 1024 不透明 PNG，含系统深色版本。
- AppLogo / BrandMark：可缩放矢量 PDF，用于导航与原生 LaunchScreen.storyboard。
- Branding/Logo.svg：矢量导出；Branding/Preview.png：图标与启动图预览。
- 启动画面在系统浅色模式采用浅灰背景与红色标识，深色模式采用深底红色标识，与 App 首屏衔接；不添加人为启动等待。

重新生成资源：

```sh
swift -module-cache-path /private/tmp/redtv-swift-module-cache Scripts/GenerateIcon.swift
```

## 页面头部

五个标签页共用 RedPageHeader / redTabPage：左侧融合标识、Red TV 与中文页名，右侧固定搜索 / 设置动作，下方一行说明。统一 20pt 内容边距与标题层级，移除重复的系统根导航标题和各页英文口号。头部固定在安全区域顶部，滚动正文时保留操作入口；详情页恢复原生返回导航。新闻从旧收藏或深链压入导航栈时使用嵌入模式，保留返回按钮。

## 构建与测试

```sh
xcodebuild -project RedTV.xcodeproj -scheme 'RedTV Run' \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build

xcodebuild -project RedTV.xcodeproj -scheme 'RedTV Run' \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

单元测试覆盖焦点选择 / 星级排序、两套排名的独立接口与地区参数、主题选项、CDN 请求头、独立 Python HMAC 参考值、URL / 请求头、真实赛事与地图统计解码、不同 ID 体系、成功码、缓存回退与过期、日期、资料库冲突和并发响应。UI 测试覆盖五个标签页、关注入口、设置及账号表单，不创建真实账号。

## 目录

```text
RedTV/Core/       完美世界签名与客户端、原生模型、BBC 与账号、缓存和关注
RedTV/Features/   赛场、赛事、数据、详情、BBC 阅读与个人资料库
RedTV/UI/         可切换的主题设计系统、比分卡片和导航
RedTV/Resources/  图标、矢量标志、启动画面与隐私清单
RedTVTests/       单元测试与公开响应夹具
RedTVUITests/     导航和表单交互测试
Scripts/          品牌生成器和公开接口复核脚本
Branding/         可编辑标识与预览图
```

2026-11-02：公开接口实测已读取当日赛程、赛事列表与详情、HLTV / Valve 排名、战队与选手数据。签名、解码、缓存、主题与导航测试在 iPhone 18 Pro / iOS 27.2 执行。

验证结果（2026-11-03）：38 项单元测试与 2 项导航交互测试均已通过（40 项，分全量回归及对位补测运行），覆盖最多三场焦点叠卡、全图 / 半场数据区别、地图徽标与 BP 流程、赛后全部地图 / 单图与选手 / 对位切换、对位方向反转及缺失分数、选手八轴与荣誉类型、五页统一头部、详情返回、排名和主题切换。Release iPhone 构建通过，版本 2.0.0 / build 2，未启用任意 HTTP 放行。图标在 29 / 44 / 60 / 120pt 检查清晰度，PDF 保持零原点媒体框，PNG 不含透明通道。
