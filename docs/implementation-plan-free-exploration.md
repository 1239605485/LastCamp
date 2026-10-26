# 末日营地 v0.6 自由探索 Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Track tasks and verification here and in docs/progress-v0.6.md.

**Goal:** 按用户的新设计文档第16.1节制作自由探索版，取消固定基地，场景与UI接近参考图。
**Architecture:** 在独立 next/ 工程基于用户提供的 LastCamp v0.5 修改，保留当前据点版和安装包。复用已有物品实例、枪械配件、门窗、同伴与存档服务；增加地区与落脚点模块；将绘制全部转到用户提供的末日像素素材。
**Tech Stack:** Godot 4.7.2 / GDScript / Android ARM64 / Windows。
**Spec:** ../../exploration-user-v0.2.md；图片 QQ_1793020814677.png。

## Global Constraints
- 用户已明确要求开始下一版，直接执行；数值采用文档建议默认。
- 不覆盖旧工程或旧存档；新版本使用独立 user data 和安装标识，不声称旧档迁移。
- 全局时钟、物品唯一归属、跨区状态保存、死亡遗物守恒。
- 无固定核心、定时返营、每夜强制攻击、共享远程仓库。
- UI来自 PostApocalypse 包，中文保留清晰字体；场景以同套素材和补充包构建。

## Review Focus
- 往返和存读档不得重新刷箱、恢复弹药或丢失家具。
- 追击不能跨区洗掉，睡眠不能跳过实际威胁。
- 死亡保留多份遗物和枪械内附配件，恢复点失效有备用。
- 容器和配件操作需校验距离、容量和所有权。
- 触控热区与像素图标大小分开；不同屏幕比例可用。

### Task 1: 世界与地区状态
- [x] 修改 next/scripts/world.gd，新增 exploration.gd；先写 tests/test_exploration.gd 并观察旧版失败。
- [x] 首次地区生成、往返、统一时间、住所、死亡与备份保存；取消核心/夜袭/全局仓库；跑测试。
### Task 2: 场景与像素UI
- [x] 修改 next/scripts/art.gd、world_view.gd、hud.gd；使用原包瓦片、UI、室内和补充物品贴图，匹配参考图的自然道路、道具密度和小人物。
- [x] 用建筑几何定义匹配真实门口和可行走室内，不改变碰撞来隐藏显示错误。
- [x] 渲染室外、室内、夜间、背包画面并检查。
### Task 3: 游戏流程与交互
- [x] 修改 next/scripts/game.gd、survival_systems.gd、tactical_systems.gd；首写自由探索行为测试。
- [x] 无基地流程、旅行入口、床位交互、睡眠、清理玻璃、感知调查/追击/搜索、救援与家具跨图。
- [x] 完整面板暂停，耗时动作返回世界提交，失败不消耗材料。
### Task 4: 整体验收与交付
- [x] 审查任务接口与场景，无未声明玩法回归；记录实际实现边界。
- [x] 运行新机制测试、触控回归、素材截图和桌面启动；修复发现的问题。
- [x] 导出 Android ARM64 与 Windows；更新操作说明与未完成项，不将桌面验证称为真机测试。
