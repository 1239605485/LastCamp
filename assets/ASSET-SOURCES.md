# 素材与使用范围

## 本轮主视觉：用户提供的 Mini DAYZ 本地资源（v0.2个人自用）
- 来源1：用户本地 `C:/Users/机修/Downloads/安卓游戏源码/minidayz-master.zip`，提取其 asset/images 下环境、建筑、人物、武器与物品图集。
- 来源2：用户本地 `MiniDayZ-main.zip` 的 docs/images 中 zed_normal_skin1、zed_fast_skin1、zed_army_skin1 图集，用于统一僵尸比例。
- 用户在本轮明确要求使用这些资源、参考Mini操作/视角/环境/大地图，并说明个人使用、不作商用。
- 原Godot包README称其为非官方学习娱乐同人，未包含可认定为原作者开放许可的声明。该资源记录不将“个人自用”改写成“已取得开放商用授权”。当前包仅作为用户个人离线版本交付，未公开上传。
- 修改：裁出16个对应枪械图标、14个配件图标；枪械图标按原主武器/手枪索引提取，主武器旋转为横向展示；环境使用原60px地块与原建筑外观/室内图，角色和敌人使用32px分向帧。PNG修改及来源保留在minidayz目录中。
- 操作设计依据：原 input_handle、aim_state、run_state 和 ranged_weapon资源，采用独立移动/瞄准/开火、停步收束散布、不同弹种和换弹时长；为安卓重新映射触摸ID。
- 大地图是本工程新建的确定性8×8街区，不声称复制了原版完整地图生成器或全部玩法。

## Orven — Wasteland Essentials RPG（免费版）
- 作者：Orven
- 来源：https://orven.itch.io/wasteland
- 获取时间：2026-10-26
- 下载文件：Wastland_Essentials_Free.zip（页面公开免费版本，upload 12331949）
- 原始许可：见 `orven/Wastland_Essentials_Free/Read me.txt`。
- **仅限非商业项目；允许修改；禁止单独转售、再分发素材。**
- 本工程当前定位为用户本地非商业测试原型。APK 内仅作为游戏组成部分使用；不要单独分发素材目录或把本源码包公开分享。
- 页面标注商业许可需购买 $2.99 起的 Premium 版本；未代用户购买，也未访问付费文件。
- 使用：16×16地形、角色/手部、僵尸、篝火、床铺、货箱、沙袋、铁丝围栏、物品图标与人物阴影。
- 修改方式：最近邻2倍绘制、裁切原图集帧、少量调色。建筑与UI为工程自制，保持地图碰撞与玩法不变。

## Noto Sans CJK SC
- 来源：https://github.com/notofonts/noto-cjk/tree/main/Sans
- SIL Open Font License 1.1，完整许可见 FONT-LICENSE.txt。

## Kenney — Tiny Town 1.1 / UI Pack Pixel Adventure 2.0
- 来源：https://kenney.nl/assets/tiny-town 与 https://kenney.nl/assets/ui-pack-pixel-adventure
- 许可：CC0；本地原始许可见 kenney/TINY-TOWN-LICENSE.txt、PIXEL-UI-LICENSE.txt。
- 使用：16×16树木，像素面板/按钮九宫格边框。
- 修改：绘制时降低亮度/饱和观感，统一到营地青灰与土褐色；PNG未改动。

## CobraLad — Post-apocalyptic 16x16 tileset [update1]
- 来源：https://opengameart.org/content/post-apocalyptic-16x16-tileset
- 作者：CobraLad；许可：CC-BY-SA 3.0。
- 原图：cobralad/apocalypse.png；完整许可：cobralad/CC-BY-SA-3.0.txt。
- 使用：废弃车辆、桶、碎石；以原尺寸2倍最近邻截取绘制，绘制时调暗；原图未修改。
- 本素材及其后续改编版本保留 CC-BY-SA 3.0。与 Orven 等素材分开存放，未合并成混合图集；本许可不被替换成工程代码许可。
- 游戏暂停界面显示作者与许可摘要；资源记录提供来源与完整许可。

## 项目自制内容
UI布局、地图与营地规则、合成音效由本工程制作。v0.2已按用户要求接入上述Mini本地美术；其他源码包未直接并入代码。

## v0.4 源码参考与显示调整

- Rogue Survivor alpha 10.1 src.zip：用户2026-10-26提供。读取Rules、MapGenerator、BaseMapGenerator、BaseTownGenerator、StdTownGenerator用于比较食物/体力和种子城镇生成的规则组织。未把其C#代码或美术资源导入APK。
- Mini player.tscn：核对四方向行走、瞄准、work帧索引。树木tree.tscn核对hframes=2，仅绘制站立帧；按可见树干修正锚点。
- Mini物品图标：运行时清理透明外缘近白描边，极小薄物件保留灰色轮廓；保留源PNG以便追溯。苹果、野莓、番茄、西葫芦继续使用用户包内对应物品和植物纹理。
