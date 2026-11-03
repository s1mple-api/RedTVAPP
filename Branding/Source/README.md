# CS 选手矢量轮廓来源

- 官方页面：https://www.counter-strike.net/cs2
- 官方样式资源：https://www.counter-strike.net/public/css/csgo_react/main.css
- 样式引用的公开 Logo：https://cdn.fastly.steamstatic.com/apps/csgo/images/csgo_react/global/logo_cs_sm.svg
- 读取日期：2026-11-02

`CSOperator.svg` 保留该官方 Logo 的第三个 path（持枪选手剪影），未使用前两个 CS 字母 path。`Scripts/GenerateIcon.swift` 读取此本地轮廓，将其嵌入 Red TV 的 R 字标电视窗口，导出图标、AppLogo、BrandMark 和品牌预览。大写 R 是小尺寸下的主体，CS 剪影为细节；无需额外叠加字标或电视外框。

生成资源不需要联网。修改 R 字形、窗口、颜色或排版时，运行项目根目录的 `swift -module-cache-path /private/tmp/red-tv-swift-module-cache Scripts/GenerateIcon.swift`。SVG 源中的剪影坐标遵循向下的 Y 轴；PDF / PNG 的生成器负责坐标转换。
