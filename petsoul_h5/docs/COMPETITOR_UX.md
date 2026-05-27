# 竞品 UX 拆解 · Soul / Petch / FetchaDate

> Pet Soul 不是简单「Tinder + 狗」，而是三家的**机制杂交**。mock 必须体现各家的**一个不可替代动作**。

---

## 1. Soul — 借什么、不借什么

| 借 | 不借 |
|----|------|
| **30 秒灵魂鉴定** → 进专属「星群 / 人格池」 | 3D 星球拨动（过重，H5 不做） |
| **合频 %  everywhere**（滑之前就看见） | 广场 Feed、语音匹配、捏脸 |
| 测完 **身份揭晓 moment**（你被分到哪类人/哪颗星球） | 真人头像优先（Soul 用 Avatar） |
| **引力签**式标签（用户自选 + 算法补） | 蓝色宇宙视觉（我们用黑白） |
| Slogan 逻辑：**跟随灵魂找到你** → 我们：**跟随狗格找到遛狗搭子** | 8 个字母 Soulmate 长线（MVP 不做） |

**Soul 的关键纠正**：Soul **不是**探探式左滑主流程；主路径是「测 → 看匹配度 → 选」。  
Pet Soul 用 **Tinder 手势** 刷很多狗，但 **Soul 的匹配 % 必须在卡上出现**，不能只在 Like 后才给。

---

## 2. Petch — 借什么、不借什么

| 借 | 不借 |
|----|------|
| **Paws-onality**（MBTI 风娱乐测试） | Bone 积分、地图、Mochi AI（后期并进主 App） |
| **按狗格 + 能量 + 体型 + 玩法** 算合频 | 全国 LBS、活动日历（MVP 不做） |
| **滑的是「狗档案」**，不是主人 dating 页 | IM 聊天（现场 MVP 不做） |
| 卡上直接看到 **为什么合频**（1 行理由） | 复杂 gamification |

Petch 卡上信息：`名字 + 品种 + paws-onality 类型 + 合频依据（能量/玩风）`。

---

## 3. FetchaDate — 借什么、不借什么

| 借 | 不借 |
|----|------|
| **WingPet 宠先出场**，主人照片 **模糊 / 后置** | Dating 定位、虚拟宠物 |
| **同一张卡三种操作**（核心！） | Matches 聊天 Tab |
| ① 直接右滑宠 | 订阅 / 付费墙 |
| ② **上滑 / 展开看主人 clues**（滑之前！） | |
| ③ **点 ? 揭晓主人**（模糊 → 清晰）再决定 | |
| Clues 是 **宠/ WingPet 口吻** 介绍主人 | |
| 「Fetch Who's Behind」游戏感 | |

**我们 mock 之前的最大问题**：clues 放在 Like **之后** — 这违反 FetchaDate。  
Clues 必须在 **决策前** 可探；Like 后是 **互相同频确认 + 现场破冰提示**，不是第一次看主人信息。

---

## 4. Pet Soul = 三合一定位

```
Soul     →  测完有「身份」+ 卡上合频 %；**初阶 16 / 全量 64 分级**
Petch    →  滑的是狗格档案 + 玩伴逻辑
FetchaDate →  WingPet 三层：宠 hero / clues / 揭晓主人
```

**不是 dating**：揭晓主人 = 方便**现场认人**，不是线上暧昧。

---

## 5. Discover 卡 · 目标结构（v2 mock）

```
┌─────────────────────────────┐
│ Discover          合频 87%  │  ← Soul/Petch
├─────────────────────────────┤
│                             │
│      [ 宠图 hero 65% ]       │
│                             │
├─────────────────────────────┤
│ Bella                       │
│ 柯基 · ENFP 社交小太阳        │  ← Petch
│ [外向] [玩瘋]                 │
├─────────────────────────────┤
│ ▲ WingPet 線索（上滑展開）    │  ← FetchaDate
│ 「B妈：週末常在氹仔海濱…」     │
├─────────────────────────────┤
│ (?) [模糊主人]  揭晓          │  ← FetchaDate tap reveal
├─────────────────────────────┤
│      ✕              ♥        │
└─────────────────────────────┘
```

**Like 后弹层**：合频 % + 现场破冰 + **主 CTA「立刻开聊」**（Soul）— 不是等对方先发。

**IM 内**：
- Petch → 结构化 Playdate 卡（时间/地点/接受）
- FetchaDate → 约会 invite 卡（咖啡/可带狗）

**单向 Like** → Fav'd tab，不解锁聊天（FetchaDate）。

---

## 6. 屏图对照（修正后）

| 屏 | Soul | Petch | FetchaDate |
|----|------|-------|------------|
| 入口 | 跟随灵魂 | 找 playdate | 宠爱好者 odds · **快速 profile** |
| 建檔 | — | **狗档案 + 照** | **WingPet 创建（宠图/clues）** |
| 测验 | 灵魂鉴定 | Paws-onality | 快速 profile |
| 结果 | 星群/人格 | 狗格类型 | WingPet 创建完成 |
| Discover | 合频 % | 狗格滑卡 | 宠先 + clues + 揭晓 |
| Match | 灵魂匹配成功 · **立刻开聊** | 玩伴合频 | Matches + **Fav'd** tabs |
| 聊天 | **匹配即开聊** banner | **Playdate 卡** | **约会 invite 卡** |
| 名片 | Avatar 主页 | 宠物档案 | 宠+主 profile |

---

## 7. MVP mock 已覆盖 / 仍不做

**mock v4 已覆盖**
- FetchaDate：Matches / Fav'd、WingPet clues、约会卡
- Petch：Playdate 结构化卡、RSVP 确认
- Soul：匹配成功 banner、立刻开聊主 CTA

**仍不做（真产品）**
- Soul：星球 3D、广场、语音
- Petch：地图、Bone、活动 RSVP 后端
- FetchaDate：完整 dating copy、GPS 5km 筛选

---

## 8. 主人信息建档（profile Step 2）

| 字段 | 来源 | Discover 怎么用 |
|------|------|-----------------|
| 主人称呼 + 年龄 + 标签 | FetchaDate | 点 ? 揭晓 → `B媽 · 28 · 設計系` |
| WingPet 线索（宠口吻） | FetchaDate | 上滑 drawer 决策前可见 |
| 主人照片 | FetchaDate | 默认模糊 + ? 揭晓 |
| 常遛狗区域 | Petch | 卡上距离/区域文案 |
| 现场破冰 | Petch + 现场 | 双向 Match 弹层认人 |

**不做**：长 bio、感情状态、多图相册、实名认证。

---

*2026-05-24 · mock v4 对齐三家完整链路*
