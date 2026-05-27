# Pet Soul · 项目记忆（单一真相源）

> **产品**：宠物的 Soul — Petch 狗格 + FetchaDate WingPet + Soul 式刷很多狗  
> **形态**：独立 H5（优先），Cloudflare Pages + Supabase；澳门部署，无需大陆服务器/备案  
> **审美**：乔布斯 + 苹果 + 喜茶 · **永远做减法**  
> **设计参考**：`设计参考/04_业务文档设计规范/设计铁律.md`（最高准则）

协作者与 AI：**改 UI / 加功能前先读本文 + 设计铁律。**

---

## 1. 产品定义

| 项 | 内容 |
|----|------|
| 一句话 | **本地**刷 WingPet · 狗格合频 · 双向 Match 后聊天约遛狗（也可约人） |
| 不是什么 | 全国陌生 dating、**远距离**网友、引荐码工具、健康问诊主产品 |
| 是什么 | **先近后聊**：同场/同区可滑 → 双向合频 → IM → playdate 或轻约会 |
| 与主 App | 验证后进 `app/`（档案 + AI 问诊 + 可选 IM/日历） |

**第一约束 = 距离。** Discover 只展示「不会太远」的对象；合频再高，跨城也不进池。

### 核心体验（不可砍）

1. **16 题灵魂鉴定（初阶）** → Paws-onality
2. **Discover 左右滑** → 很多 WingPet；卡上 **距离/同场** + 合频 %
3. **WingPet 三层** → 宠 hero / 上滑 clues / ? 揭晓主人
4. **双向 Match** → 才解锁 IM 与约时间
5. **实时进池** → 测完 INSERT；队列 **按 event 或 geo 过滤**

### 分阶段（距离 → Match → IM → 约）

| 阶段 | 距离 | Match 后 |
|------|------|----------|
| **Hackathon** | 同 `event_id`（等同全场同城） | 双向 Match → 破冰弹层 → **轻 IM 或微信引导** → 口头/playdate 模板 |
| **V1** | 同城 / ≤5 km（需授权或选区） | 双向 → **Supabase IM** → 发 playdate 卡片 |
| **V2** | 地图 + 常遛狗点 | IM + 日历 RSVP + 主 App 并入 |

### MVP 刻意不做（Hackathon 当日）

- 全国池、精确 GPS 轨迹、Bone 积分、App Store 首日、**无双向 Match 就开放聊天**

---

## 2. 技术框架

```
┌─────────────────────────────────────────┐
│  H5  Vue 3 + Vite + TypeScript + Pinia   │
│  Cloudflare Pages（静态，HTTPS，澳门可用） │
└──────────────────┬──────────────────────┘
                   │ @supabase/supabase-js
┌──────────────────▼──────────────────────┐
│  Supabase（Singapore 区域）               │
│  · soul_cards（event_id + payload）      │
│  · swipes（session_id, card_id, dir）    │
│  · Realtime INSERT 或 30s 轮询兜底        │
└─────────────────────────────────────────┘
可选：Railway BFF（限流/feed）— 非 Day 1 必须
```

| 决策 | 选择 | 原因 |
|------|------|------|
| 前端 | Vue 3 + Vite + TS | 滑卡状态、测验表单、一天可上线 |
| 托管 | Cloudflare Pages | 静态 CDN，无运维，微信可开 |
| 数据 | Supabase | 已有栈；Realtime 或轮询 |
| 服务器 | **不需要 VPS** | 人多压 Supabase，不压自建机 |
| 区域 | Supabase **Singapore** | 澳门延迟友好 |

### 路由（H5）

| 路径 | 屏 | 优先级 | 说明 |
|------|-----|--------|------|
| `/` | **入口 Landing** | P0 | 扫码默认；活动名 +「开始鉴定」；可跳过直刷 |
| `/profile` | **填写基本信息** | P0 | Step1 宠 · Step2 主人（FetchaDate clues/揭晓 + Petch 区域/破冰） |
| `/quiz` | 灵魂鉴定 | P0 | 16 题；无花哨进度条 |
| `/result` | **狗格揭晓** | P0 | 测完 moment；展示 Paws-onality +「已入池」→ Discover |
| `/discover` | **滑卡** | P0 | 主屏；Tinder 左右滑 |
| — | Soul Match 弹层 | P1 | Like 后；合频 % + WingPet clues（非独立路由亦可） |
| `/discover`（空） | 池子空状态 | P1 | 活动刚开始；引导测验 / 刷新 |
| `/c/:slug` | 公开名片 | P1 | 分享 deep link；WingPet 完整卡 |
| `/me` | 我的 QR + 合频列表 | P1 | 入口进 Matches / Chat |
| `/matches` | 双向合频列表 | P1 | 点进聊天 |
| `/chat/:matchId` | IM | V1 | Match 解锁后才可进 |

**完整 mock**：`mock/index.html`（7 屏 + 2 状态 + 1 弹层；Matches/Chat 待补）

### 数据（最小）

**soul_cards**：`slug`, `event_id`, `payload`（`petPhoto`, `petName`, `breed`, `personaCode`, `personaTitle`, `tags`, `ownerNickname`, `ownerAge`, `ownerTag`, `ownerClue`, `ownerPhoto`, `ownerRevealed`, `playArea`, `iceHint`, `intent`）, `created_at`

**storage（V1）**：Supabase Storage bucket `pet-photos` · 寵 hero 必填 · 主人照可选（Discover 模糊）

**swipes**：`session_id`, `card_id`, `direction`（like/pass）, `created_at`

**matches**：`event_id`, `card_a`, `card_b`, `matched_at`（双向 like 才 INSERT）

**messages**（V1+）：`match_id`, `sender_session`, `body`, `kind`（text / playdate / date）, `created_at`

**geo（V1+）**：卡片 payload 含 `lat`, `lng`, `area_label`（如「氹仔」）；Discover 过滤 `distance ≤ max_km`

**Discover 逻辑**：拉本场 `event_id`（或 geo 半径内）且未滑过的卡 → 排除自己 → Realtime append。

---

## 3. 信息架构 · 做减法

### 屏数原则（乔布斯：能少一屏就少一屏）

| 优先级 | 屏 | 元素上限 |
|--------|-----|----------|
| P0 | **入口 Landing** | 活动名 + 1 句价值 + 黑 CTA；可「直接刷」 |
| P0 | **WingPet 建檔** | Step1 寵照+名字+品種；Step2 **FetchaDate 主人** + **Petch 玩伴** |
| P0 | **测验** | **初阶 16 题**（4 维度×4）；点选自动下一题；~2 分钟 |
| P0 | **狗格揭晓** | 宠图 + ENFP + 梗名 +「已入池」→ Discover |
| P0 | **Discover 滑卡** | 1 张卡全屏；宠图 + 名字 + 1 行狗格 + 2 tag；底 ✕ / ♥ |
| P1 | **配对弹层** | 合频数字 + 1 句话 + clues；1 个按钮关闭 |
| P1 | **Discover 空池** | 引导测验 / 刷新；无插画堆叠 |
| P1 | **公开名片** | `/c/:slug`；分享用 |
| P2 | 我的 QR | 仅当需要分享时 |
| 禁止 | 底部 5 Tab、设置页、编辑资料长表单、聊天 IM | — |

### 滑卡交互（三合一对齐）

**FetchaDate（同一张卡、决策前）**
- 宠图 hero 全屏；主人照片 **模糊**，点 **?** 揭晓（Fetch Who's Behind）
- **上滑 / 点 handle** 展开 WingPet 线索（宠口吻介绍主人）— **不是** Like 后才给

**Soul + Petch（决策前）**
- 卡上显示 **合频 %** + 一行「为什么合频」（能量/玩风/体型）
- Paws-onality 类型常驻卡面

**Like 后（Soul Match 弹层）**
- 互相同频确认 + **现场破冰提示**（认人/破冰句）— 不是聊天入口

- 右滑 / ♥ → Like → 弹层 → 下一张  
- 左滑 / ✕ → Pass → 下一张  
- 预加载当前 + 2 张；队列 &lt; 3 时拉下一页  

详见 `docs/COMPETITOR_UX.md`

### 刷到合适的 · 下一步（距离优先 → 双向 → IM → 约）

> **2026-05 共识**：可以走 **双向 Match → 聊天 → 约 playdate/约会**；但 **距离是第一筛选**，不做远距离社交。

#### 定位怎么摆

| 层级 | 规则 |
|------|------|
| **L0 距离** | 硬过滤：同场 `event_id` / 同区 / ≤5 km；卡上显示「同场 · 50m」「氹仔 · 1.2km」 |
| **L1 狗格** | 合频 % = **55% 主人 Soul + 35% 狗玩伴 + 10% 意图**（详见 `docs/MATCH_SPEC.md`） |
| **L2 意图** | 主人自选 tag：**遛狗搭子** / **都可** / **交友向**（软匹配，减少误会） |
| **L3 双向** | 仅双方 ♥ 才生成 `match`，解锁 IM |
| **L4 线下** | playdate（时间+地点+带狗）或轻约会（咖啡/可带狗）— **都在 IM 里用模板发起** |

**主叙事仍是宠先（WingPet）**；约会允许，但不做成 FetchaDate 纯 dating 首页。

#### 推荐用户路径（完整版 · V1 目标）

```
Discover（仅附近/同场）
  → 上滑 clues / ? 主人 → ♥
       ↓
  对方也 ♥？
    ├─ 否 → 「我的收藏」；继续刷
    └─ 是 → Soul Match 弹层（合频 + 距离 + 意图 tag）
              ↓
         [ 立刻开聊 ] → /chat/:matchId?new=1（Soul：匹配即开聊）
              ↓
         IM：Soul banner + 文本 + 快捷按钮
              · 「约遛狗」→ Petch playdate 卡片（何时何地 · 接受）
              · 「约见面」→ FetchaDate 约会 invite 卡
              ↓
         成行 → 现场或下次；留存进主 App

  单向 ♥ → Fav'd（FetchaDate）；不解锁 IM，等对方回 ♥
```

#### Hackathon 当日（最小闭环）

同 `event_id` = 全员「够近」；不做 GPS 也能演示距离逻辑（文案写 **同场 · 现场**）。

| 步骤 | 做 | 可砍 |
|------|-----|------|
| 双向 Match | ✅ 必须 | |
| 弹层 | 合频 + **同场** + 破冰 | |
| IM | Supabase 3 条文本够用 | 完整已读/推送 |
| 约 | IM 里 **固定模板**「明天 17:00 氹仔海濱遛狗？」 | 日历 RSVP |

#### 和竞品对齐

| | FetchaDate | Petch | Pet Soul |
|---|------------|-------|----------|
| 距离 | 隐含同城 | **附近** map | **L0 硬约束** |
| Match 后 | Chat → 约会 | **IM → playdate** | 两者都要，**遛狗模板默认** |
| 宠先 | WingPet | 狗档案 | WingPet + 狗格 |

#### 弹层 / IM（mock v4）

- `result.html` — 测验后选意图（遛狗搭子 / 都可 / 交友向）
- `matches.html` — **Matches | Fav'd** tabs · 距离 + 意图
- `discover.html` — 双向 →「立刻开聊」；单向 → Fav'd
- `chat.html` — Soul banner · Petch Playdate 卡 · FetchaDate 约会卡 · RSVP 确认

#### 不做

- 无距离上限的全国刷、纯匿名跨城聊天、Match 前 DM

## 4. 设计语言 · 乔布斯 + 苹果 + 喜茶

> 提炼自 `设计参考/04_业务文档设计规范/设计铁律.md` 与 `awesome-design-md/apple/DESIGN.md`  
> **Pet Soul 适配**：保留苹果结构/留白/字阶；**禁用设计铁律中的蓝色与米色**（与 Apple 营销站蓝 CTA 不同，本项目用黑 CTA）。

### 4.1 最高原则

1. **先减后加**：先问「删掉它用户还懂吗？」— 懂就删。  
2. **宠物是主角**：界面退后，**狗/图占 60%+**，UI 是画廊墙。  
3. **一屏一事**：Discover 只做滑卡；测验只做题。  
4. **留白 &gt; 信息密度**（喜茶 / 苹果 Settings）。  
5. **娱乐向**：狗格/MBTI 角标小字 + disclaimer，不做算命 UI。

### 4.2 配色（Pet Soul · 黑白灰）

| Token | 值 | 用法 |
|-------|-----|------|
| `--bg` | `#ffffff` | 主背景 |
| `--bg-2` | `#f5f5f7` | 次背景、宠图底场（苹果浅灰） |
| `--ink` | `#1d1d1f` | 标题、主按钮、Tab active |
| `--ink-2` | `#424245` | 副标题 |
| `--ink-3` | `#86868b` | 说明、clues |
| `--ink-4` | `#c7c7cc` | 占位、disabled |
| `--line` | `rgba(0,0,0,0.06)` | 分隔 |
| `--alert` | `#ff3b30` | **仅**未读小圆点，惜用 |

**禁用（违反即打回）**

- ❌ 蓝色 `#0071e3` / navy（用户审美明确拒绝）  
- ❌ 米色 / cream / beige 背景  
- ❌ 大面积 `#000` 黑底（内部页）  
- ❌ box-shadow 装饰（用边框 + 留白）  
- ❌ 渐变光斑、金色装饰、emoji 堆叠 UI  

**主推/CTA**：黑底白字按钮 / 黑色描边 chip — 不用彩色 CTA。

### 4.3 字体（H5 可用系统栈）

| 阶 | 用途 | 大小 | 字重 |
|----|------|------|------|
| Display | 宠物名 | 22px | 500（不要 28 bold） |
| Title | 狗格梗名 | 15–17px | 500 |
| Body | clues / 说明 | 13–14px | 400 |
| Caption | ENFP / 娱乐 disclaimer | 11–12px | 400 |
| Eyebrow | SOUL · WINGPET | 10px | 600，letter-spacing 0.12em |

```css
font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'PingFang SC', sans-serif;
```

- 标题 **负 tracking**（苹果感）：`-0.02em` 量级  
- 正文行高：1.45–1.5；Display 行高：1.1  

### 4.4 形状与组件

| 元素 | 规则 |
|------|------|
| 卡片圆角 | **8px**（不要 16–24 SaaS 大圆角） |
| 主按钮 | 黑底 `#1d1d1f`，白字，圆角 **8px**，高 44px |
| 次按钮 | 透明 + 1px `--line` 边框 |
| 滑卡 | **无边框**；宠图区 `#f5f5f7` 实底，无渐变 |
| Tag | 11px pill，`#f5f5f7` 底，不要彩色 badge 墙 |
| 弹层 | 白底，顶圆角 16px；**不用**重阴影 |

### 4.5 喜茶借鉴点

- **单列长列表式** clarity：少分区、少卡片套卡片  
- **「我的」级简化**：身份 + 一个数字（合频/已刷）+ 一个动作  
- 点单页式 **左侧不做了** — Discover 全屏一张卡更像「专注选一只」  

### 4.6 苹果借鉴点

- 产品即 hero：狗图居中，solid field  
- 交互色 **仅黑**（本项目不用 Apple Blue）  
- 模块间距 **36–40px**；菜单项 padding **19–22px**  

### 4.7 WingPet 卡结构（Discover）

```
┌────────────────────────┐
│                        │
│     [ 宠图 / emoji ]    │  ← 60–70% 高度，#f5f5f7
│                        │
│  Bella                 │  22px medium
│  柯基 · 社交小太阳       │  13px ink-3
│  ENFP · 娱乐向          │  11px caption
│                        │
│  [ ✕ ]          [ ♥ ]  │  固定底栏，44px 触控
└────────────────────────┘
```

主人信息 **默认不在首屏**；Like 后或上滑才见 clues。

---

## 5. 现场活动（event）

- 固定 `event_id`（如 `macau-hack-20260525`）  
- 入口 QR：`https://域名/?e=EVENT_ID`  
- 开赛前 seed **5–10 张 demo** 同 event_id  
- 大屏可选：`(count soul_cards where event_id=…)`  

---

## 6. 与竞品差异（对外一句）

Petch 有狗格滑卡；FetchaDate 有 WingPet；**Pet Soul = 两者合体 + Soul 式刷很多 + 现场池子越长越多** — 不是 dating，不是引荐码。

---

## 7. 文件与参考索引

| 路径 | 用途 |
|------|------|
| **`mock/index.html`** | **HTML 审美 mock 索引**（quiz / discover / me） |
| **`docs/QUIZ_SPEC.md`** | 竞品题量 + 初阶 16 题四维规格 |
| **`docs/COMPETITOR_UX.md`** | Soul / Petch / FetchaDate 机制拆解 |
| **`mock/js/match-engine.js`** | 双层匹配引擎 · 测验向量 → 合频分 |
| **`mock/js/matches-data.js`** | 合频 / 聊天 mock 数据 |
| **`mock/js/questions.js`** | 题库数据（Vue 版直接 import） |
| `设计参考/04_业务文档设计规范/设计铁律.md` | **审美最高准则** |
| `设计参考/04_业务文档设计规范/小程序设计规范SKILL.md` | 字号/禁用清单/喜茶式排版 |
| `设计参考/03_设计图/awesome-design-md/design-md/apple/DESIGN.md` | 留白、字阶、产品 hero（**色不要用 Apple Blue**） |
| `设计参考/03_设计图/v2-设计稿/v5_我的_审美档案.html` | 苹果 Settings 式密度参考 |
| 仓库根 `AGENT.md` | 主 App Pet Health；Pet Soul 验证后并入 |
| 仓库根 `app/` | Flutter 健康 App，非 H5 首日范围 |

---

## 8. 实现检查清单（每次 PR / 演示前）

- [ ] Discover 是否 **一次只展示一张卡**、信息 ≤ 5 个视觉块？  
- [ ] 是否 **无蓝色、无米色、无 shadow**？  
- [ ] CTA 是否 **仅黑色**？  
- [ ] 测完是否 **自动进池 + 可滑到新卡**？  
- [ ] 微信扫 QR 是否 **3 秒内可交互**？  
- [ ] 底部是否有 **多余 Tab**？（MVP 应否）  
- [ ] disclaimer：「娱乐向性格测试」是否可见？  

---

## 9. 版本记录

| 日期 | 说明 |
|------|------|
| 2026-05-24 | 初版：H5 框架 + 滑卡 + Supabase + 设计铁律提炼 |
