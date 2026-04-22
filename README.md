# 🐾 Pet Health App

> 一款面向 iOS 的宠物健康管理应用，集健康档案、生命时光轴、每日健康记录与 AI 辅助问诊于一体。

[![Backend CI](https://github.com/xiao222xian/pet-health-app/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/xiao222xian/pet-health-app/actions/workflows/backend-ci.yml)
[![Flutter CI](https://github.com/xiao222xian/pet-health-app/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/xiao222xian/pet-health-app/actions/workflows/flutter-ci.yml)

---

## 目录

- [产品功能](#产品功能)
- [技术架构](#技术架构)
- [项目结构](#项目结构)
- [数据库设计](#数据库设计)
- [API 文档](#api-文档)
- [本地开发](#本地开发)
- [部署指南](#部署指南)
- [iOS 上架流程](#ios-上架流程)
- [成本说明](#成本说明)
- [路线图](#路线图)

---

## 产品功能

### 🏥 健康档案管理
- 记录宠物基础信息：名字、物种、品种、出生日期、体重、性别、绝育状态
- 医疗记录管理：疫苗、体检、驱虫、过敏史、疾病史
- 智能提醒：根据 `next_due_date` 自动在首页展示即将到期的疫苗/体检提醒

### 📸 生命时光轴
- 按时间倒序展示成长记录
- 支持四类事件：照片里程碑、体重变化、医疗记录、自由笔记
- 支持每条记录附带多张照片（Supabase Storage）

### 📊 每日健康记录
- 每日记录：饮食类型与用量、饮水量、体重、排便状态（1-5 级）、食欲（1-5 级）、备注
- 每个宠物每天唯一一条记录（数据库 UNIQUE 约束）
- 历史记录列表（最近 30 天）

### 🤖 AI 辅助问诊
- 输入症状描述，AI 返回风险等级与建议
- 风险等级：`low`（轻微）/ `medium`（中等）/ `high`（严重）/ `emergency`（紧急）
- 所有 AI 响应强制附带免责声明
- 问诊记录自动保存至数据库
- **强制使用须知弹窗**：用户确认后方可使用

---

## 技术架构

### 技术栈

| 层级 | 技术选型 | 说明 |
|------|---------|------|
| 移动端 | Flutter 3.x (iOS) | Cupertino 原生风格，iOS 优先，Android 复用同一套代码 |
| 后端 | Node.js 20 + TypeScript | Express 框架，部署在 Railway |
| 数据库 | Supabase (PostgreSQL 15) | Auth + DB + Storage 一体化，含 RLS 行级安全 |
| 文件存储 | Supabase Storage | 宠物照片与头像，CDN 加速 |
| AI | OpenRouter API | 问诊与营养建议走 OpenRouter 兼容接口，可切换免费模型 |
| CI/CD | GitHub Actions | 后端 + Flutter 双 workflow，push 自动触发 |

### 系统架构图

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter iOS App                      │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │  档案    │  │ 时光轴   │  │  健康    │  │  问诊  │  │
│  │ Profile  │  │ Timeline │  │HealthLog │  │Consult │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              GoRouter Navigation                 │   │
│  └──────────────────────────────────────────────────┘   │
└────────┬──────────────────────────┬────────────────────┘
         │                          │
    直接 SDK 调用               HTTPS API 调用
    (CRUD 操作)                (AI 功能代理)
         │                          │
┌────────▼──────────┐    ┌──────────▼──────────────────┐
│     Supabase      │    │   Node.js API (Railway)     │
│                   │    │                             │
│  ┌─────────────┐  │    │  POST /api/v1/consult       │
│  │    Auth     │  │    │  POST /api/v1/nutrition     │
│  │ (JWT/Apple) │  │    │                             │
│  ├─────────────┤  │    │  ┌─────────────────────┐   │
│  │ PostgreSQL  │  │    │  │  Supabase JWT 验证   │   │
│  │  (6 tables) │  │    │  └──────────┬──────────┘   │
│  ├─────────────┤  │    │             │               │
│  │   Storage   │  │    │  ┌──────────▼──────────┐   │
│  │  (photos)   │  │    │  │   Anthropic Claude  │   │
│  └─────────────┘  │    │  │  (Haiku / Sonnet)   │   │
└───────────────────┘    │  └─────────────────────┘   │
                         └─────────────────────────────┘
```

### 安全设计

- **Row Level Security (RLS)**：所有数据表均开启 RLS，用户只能读写自己的数据
- **JWT 验证**：后端所有 AI 接口在调用 Claude 前先验证 Supabase JWT
- **密钥管理**：所有密钥通过环境变量注入，不进入版本库
- **HTTPS 强制**：前端→后端、后端→Anthropic 全链路 HTTPS
- **图片压缩**：客户端上传前限制单张 ≤1MB

---

## 项目结构

```
pet-health-app/
│
├── README.md                        # 本文档
├── LICENSE                          # MIT
├── .gitignore                       # Node / Flutter / iOS / 密钥 忽略规则
├── .env.example                     # 环境变量模板
│
├── .github/
│   └── workflows/
│       ├── backend-ci.yml           # 后端 CI：类型检查 + 单元测试
│       └── flutter-ci.yml          # Flutter CI：analyze + test
│
├── supabase/
│   └── migrations/                  # SQL 迁移文件（按序执行）
│       ├── 001_profiles.sql         # 用户档案表 + 新用户触发器
│       ├── 002_pets.sql             # 宠物信息表
│       ├── 003_medical_records.sql  # 医疗记录表
│       ├── 004_timeline_events.sql  # 时光轴事件表
│       ├── 005_health_logs.sql      # 每日健康记录表
│       ├── 006_consult_sessions.sql # AI 问诊记录表
│       └── 007_rls_policies.sql     # 所有表的行级安全策略
│
├── backend/                         # Node.js + TypeScript 后端
│   ├── src/
│   │   ├── index.ts                 # Express 服务入口
│   │   ├── types/
│   │   │   └── index.ts             # 共享 TypeScript 类型定义
│   │   ├── middleware/
│   │   │   └── auth.ts              # Supabase JWT 验证中间件
│   │   ├── services/
│   │   │   └── claude.ts            # Anthropic Claude API 封装
│   │   └── routes/
│   │       ├── consult.ts           # POST /api/v1/consult
│   │       └── nutrition.ts         # POST /api/v1/nutrition
│   ├── tests/
│   │   ├── auth.test.ts             # 认证中间件单元测试（3个）
│   │   └── consult.test.ts          # 问诊路由集成测试（2个）
│   ├── package.json
│   └── tsconfig.json
│
├── app/                             # Flutter iOS 应用
│   └── lib/
│       ├── main.dart                # 应用入口，初始化 Supabase
│       ├── app/
│       │   ├── router.dart          # GoRouter 路由配置 + Auth 守卫
│       │   └── theme.dart           # Cupertino 主题色彩定义
│       ├── shared/
│       │   ├── models/              # Dart 数据模型（fromJson/toJson）
│       │   │   ├── pet.dart
│       │   │   ├── medical_record.dart
│       │   │   ├── timeline_event.dart
│       │   │   ├── health_log.dart
│       │   │   └── consult_session.dart
│       │   ├── services/
│       │   │   ├── supabase_service.dart  # Supabase 客户端封装
│       │   │   └── api_service.dart       # 后端 HTTP 调用封装
│       │   └── widgets/
│       │       ├── app_card.dart          # 通用卡片组件（阴影 + 圆角）
│       │       └── loading_overlay.dart   # 全屏加载遮罩
│       └── features/
│           ├── auth/
│           │   └── auth_screen.dart       # 登录/注册页面
│           ├── home/
│           │   └── home_screen.dart       # Tab Bar 导航容器
│           ├── profile/
│           │   ├── pet_profile_screen.dart    # 宠物档案首页
│           │   ├── pet_form_screen.dart        # 新增/编辑宠物表单
│           │   └── medical_records_screen.dart # 医疗记录列表
│           ├── timeline/
│           │   ├── timeline_screen.dart        # 时光轴列表
│           │   └── event_form_screen.dart      # 添加时光轴事件
│           ├── health_log/
│           │   └── health_log_screen.dart      # 每日健康记录
│           └── consult/
│               └── consult_screen.dart         # AI 问诊（含免责声明）
│
└── docs/
    ├── DEPLOYMENT.md                # 完整部署指南
    └── superpowers/
        ├── specs/                   # 产品设计文档
        └── plans/                   # 实施计划文档
```

---

## 数据库设计

### ER 图

```
auth.users (Supabase 内置)
    │
    └──► profiles (id, display_name, avatar_url)
              │
              └──► pets (id, user_id, name, species, breed,
                         birth_date, weight_kg, gender, neutered)
                         │
                         ├──► medical_records
                         │    (type, title, record_date, next_due_date, notes)
                         │
                         ├──► timeline_events
                         │    (type, title, content, photo_urls[], event_date)
                         │
                         ├──► health_logs
                         │    (log_date★, food_type, food_amount_g, water_ml,
                         │     weight_kg, stool_status, appetite_level)
                         │    ★ UNIQUE(pet_id, log_date)
                         │
                         └──► consult_sessions
                              (symptoms, photo_urls[], ai_response JSONB,
                               risk_level)
```

### 表结构详情

<details>
<summary>点击展开所有表结构</summary>

#### profiles
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID PK | 关联 auth.users.id，级联删除 |
| display_name | TEXT | 用户昵称 |
| avatar_url | TEXT | 头像地址 |
| created_at | TIMESTAMPTZ | 创建时间 |
| updated_at | TIMESTAMPTZ | 更新时间 |

#### pets
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID PK | 主键 |
| user_id | UUID FK | 关联 profiles.id，级联删除 |
| name | TEXT NOT NULL | 宠物名字 |
| species | TEXT CHECK | dog / cat / other |
| breed | TEXT | 品种（可选） |
| birth_date | DATE | 出生日期（用于计算年龄） |
| weight_kg | DECIMAL(5,2) | 体重（千克） |
| gender | TEXT CHECK | male / female / unknown |
| neutered | BOOLEAN | 是否绝育，默认 false |
| avatar_url | TEXT | 头像图片地址 |

#### medical_records
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID PK | 主键 |
| pet_id | UUID FK | 关联 pets.id，级联删除 |
| type | TEXT CHECK | vaccine / checkup / deworming / allergy / disease |
| title | TEXT NOT NULL | 记录标题 |
| record_date | DATE NOT NULL | 记录日期 |
| next_due_date | DATE | 下次到期日（用于提醒，可为空） |
| notes | TEXT | 备注 |

#### timeline_events
| 字段 | 类型 | 说明 |
|------|------|------|
| type | TEXT CHECK | photo / weight / medical / note |
| photo_urls | TEXT[] | 照片地址列表，默认空数组 |
| event_date | DATE NOT NULL | 事件日期 |

#### health_logs
| 字段 | 类型 | 说明 |
|------|------|------|
| log_date | DATE NOT NULL | 记录日期，与 pet_id 联合唯一 |
| food_type | TEXT | 食物类型描述 |
| food_amount_g | INTEGER | 进食量（克） |
| water_ml | INTEGER | 饮水量（毫升） |
| weight_kg | DECIMAL(5,2) | 当日体重 |
| stool_status | SMALLINT(1-5) | 排便状态：1=异常 5=正常 |
| appetite_level | SMALLINT(1-5) | 食欲等级：1=无食欲 5=旺盛 |

#### consult_sessions
| 字段 | 类型 | 说明 |
|------|------|------|
| symptoms | TEXT NOT NULL | 症状描述文字 |
| photo_urls | TEXT[] | 上传图片地址列表 |
| ai_response | JSONB | AI 完整响应对象 |
| risk_level | TEXT CHECK | low / medium / high / emergency |

</details>

### RLS 行级安全策略

所有表均启用 Row Level Security，核心策略逻辑：

```sql
-- 用户只能访问自己的档案
profiles:  id = auth.uid()

-- 用户只能访问自己的宠物
pets:  user_id = auth.uid()

-- 宠物关联表：通过 pets 表验证所有权
medical_records / timeline_events / health_logs / consult_sessions:
  pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid())
```

---

## API 文档

### Base URL

```
https://your-app.up.railway.app/api/v1
```

### 认证

所有接口需要在 Header 中携带 Supabase JWT：

```
Authorization: Bearer <supabase_access_token>
```

后端通过 Supabase Service Role Key 验证 token 有效性，并从中提取 `user_id`。

---

### POST /consult — AI 症状分诊

**Request Body:**
```json
{
  "pet_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
  "symptoms": "精神不振，食欲下降，持续咳嗽两天",
  "photo_urls": ["https://storage.supabase.co/..."]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| pet_id | UUID | 是 | 必须属于当前用户 |
| symptoms | string | 是 | 5-1000 字 |
| photo_urls | string[] | 否 | 最多 3 张，必须为合法 URL |

**Response 200:**
```json
{
  "risk_level": "medium",
  "summary": "宠物出现呼吸道症状，建议尽快就医排查。",
  "advice": [
    "观察咳嗽频率和痰液性状",
    "保持环境通风，避免刺激性气味",
    "建议 48 小时内带宠物就诊"
  ],
  "seek_vet": true,
  "disclaimer": "本结果仅供参考，不构成兽医诊断意见。如有紧急情况请立即就医。"
}
```

**风险等级说明：**
| risk_level | 含义 | App 颜色 |
|---|---|---|
| low | 轻微，可在家观察 | 绿色 `#61D9A5` |
| medium | 中等，建议就医 | 橙色 `#FFB347` |
| high | 严重，尽快就医 | 深橙 `#FF8C42` |
| emergency | 紧急，立即就医 | 红色 `#FF6B6B` |

---

### POST /nutrition — AI 营养建议

**Request Body:**
```json
{
  "pet_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
}
```

**Response 200:**
```json
{
  "daily_calories": 450,
  "protein_ratio": 0.28,
  "recommendations": [
    "选择以鸡肉或鱼肉为主要蛋白质来源的狗粮",
    "每日分两次喂食，避免一次性大量进食"
  ],
  "foods_to_avoid": [
    "葡萄和葡萄干",
    "巧克力",
    "洋葱和大蒜"
  ]
}
```

---

### 统一错误格式

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid token"
  }
}
```

| code | HTTP 状态 | 说明 |
|------|----------|------|
| UNAUTHORIZED | 401 | Token 缺失或无效 |
| INVALID_INPUT | 400 | 请求参数不合法（Zod 验证失败） |
| NOT_FOUND | 404 | 宠物不存在或不属于当前用户 |
| AI_ERROR | 503 | Anthropic API 调用失败 |
| INTERNAL_ERROR | 500 | 服务器内部错误 |

---

## 本地开发

### 环境要求

| 工具 | 最低版本 |
|------|---------|
| Node.js | 20.x |
| Flutter | 3.19+ |
| Xcode | 15+（iOS 真机/模拟器调试） |
| CocoaPods | 最新版 |
| Git | 任意版本 |

### 第一步：克隆与配置

```bash
git clone https://github.com/xiao222xian/pet-health-app.git
cd pet-health-app
cp .env.example .env
# 编辑 .env，填入以下密钥：
# SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, ANTHROPIC_API_KEY
```

### 第二步：初始化 Supabase 数据库

1. 在 [supabase.com](https://supabase.com) 创建新项目
2. 进入 **SQL Editor**，按顺序执行以下 7 个迁移文件：

```sql
-- 在 Supabase SQL Editor 中依次粘贴执行：
-- 1. supabase/migrations/001_profiles.sql
-- 2. supabase/migrations/002_pets.sql
-- 3. supabase/migrations/003_medical_records.sql
-- 4. supabase/migrations/004_timeline_events.sql
-- 5. supabase/migrations/005_health_logs.sql
-- 6. supabase/migrations/006_consult_sessions.sql
-- 7. supabase/migrations/007_rls_policies.sql
```

3. **Authentication → Providers → Email** 确保已启用
4. 复制 Project URL 和 anon key，填入 `.env`

### 第三步：启动后端

```bash
cd backend
npm install
npm run dev
# 输出：Server running on port 3000

# 验证服务正常：
curl http://localhost:3000/health
# 返回：{"status":"ok"}
```

### 第四步：运行 Flutter 应用

```bash
# 确保 iOS 模拟器已启动
open -a Simulator

cd app
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

### 第五步：运行测试

```bash
# 后端单元测试（5个）
cd backend
npm test

# Flutter 静态分析
cd app
flutter analyze     # 0 issues expected

# Flutter 单元测试
flutter test
```

---

## 部署指南

### 后端部署到 Railway

1. 访问 [railway.app](https://railway.app) → New Project → Deploy from GitHub repo
2. 选择本仓库，**Root Directory** 设为 `backend/`
3. 在 **Variables** 面板添加以下环境变量：

```
SUPABASE_URL              = https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY = eyJhb...（service role，非 anon key）
OPENROUTER_API_KEY        = sk-or-v1-...
OPENROUTER_MODEL          = openrouter/auto
GROQ_API_KEY              = gsk_...
GROQ_MODEL                = llama-3.1-8b-instant
GEMINI_API_KEY            = AIza...
GEMINI_MODEL              = gemini-flash-latest
NODE_ENV                  = production
PORT                      = 3000
```

4. Build Command：`npm run build`
5. Start Command：`node dist/index.js`
6. 部署成功后记录域名（如 `https://pet-health.up.railway.app`）

### iOS 应用构建与打包

```bash
cd app

# 生产构建（需要 Apple Developer 账号）
flutter build ios \
  --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=API_BASE_URL=https://pet-health.up.railway.app/api/v1
```

然后在 Xcode 中：
1. 打开 `app/ios/Runner.xcworkspace`
2. 设置 Bundle Identifier（如 `com.yourname.pethealthapp`）
3. Signing & Capabilities → 选择你的 Team（需要 Apple Developer 账号）
4. **Product → Archive** → **Distribute App → App Store Connect**

> 完整部署步骤详见 [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

---

## iOS 上架流程

### App Store 审核关键事项

| 事项 | 要求 |
|------|------|
| 应用分类 | **Health & Fitness**（不要选 Medical） |
| AI 问诊合规 | 首次使用强制弹出免责声明，用户点击确认后方可使用 |
| 免责声明 | 所有 AI 响应末尾显示"本结果仅供参考，不构成兽医诊断意见" |
| 应用描述 | 不得出现"诊断"等医疗术语 |
| 隐私政策 | 上架前必须提供隐私政策 URL，说明收集的数据类型 |
| Apple Sign-In | 接入第三方登录时必须同时提供 Apple Sign-In（目前仅 Email 登录，暂不需要）|

### TestFlight 测试计划

```
阶段一：内部测试（最多 100 人）
  ├─ 核心功能：注册登录 → 创建宠物档案 → 添加医疗记录
  ├─ 时光轴：添加事件、查看列表
  ├─ 健康记录：创建每日记录、查看历史
  └─ AI 问诊：输入症状 → 查看风险分级 → 确认免责声明流程

阶段二：外部 Beta 测试
  ├─ 邀请真实宠物主人参与测试
  ├─ 收集 UX 反馈，重点关注问诊功能体验
  └─ 修复问题后提交正式审核
```

---

## 成本说明

| 服务 | 免费额度 | MVP 付费方案 | 说明 |
|------|---------|------------|------|
| Supabase | 500MB DB、1GB 存储、50k MAU | Pro $25/月 | 超出免费额度后升级 |
| Railway | 免费额度 $5/月 | Starter $5/月 | 后端 API 服务器 |
| Anthropic API | 按用量计费 | 约 $0.25/1000 次问诊 | 使用 Haiku 模型 |
| Apple Developer | — | $99/年 | iOS 上架必须 |
| GitHub Actions | 2000 分钟/月（免费） | — | CI/CD 流程 |

**MVP 月运营成本（小规模用户）：约 ¥220/月（$30-35）**

---

## 路线图

### v1.0 — 当前 MVP ✅
- [x] Email 注册/登录
- [x] 宠物档案 CRUD（名字、品种、出生日期、体重、性别、绝育）
- [x] 医疗记录管理（疫苗/体检/驱虫/过敏/疾病）
- [x] 即将到期提醒展示
- [x] 生命时光轴（照片/体重/医疗/笔记）
- [x] 每日健康记录（饮食/饮水/体重/排便/食欲）
- [x] AI 症状分诊（Claude Haiku + 免责声明）
- [x] 营养建议 API（Claude Sonnet）
- [x] Supabase RLS 数据隔离
- [x] GitHub Actions CI/CD

### v1.1 — 体验完善
- [ ] Apple Sign-In 集成
- [ ] 宠物头像上传（Supabase Storage）
- [ ] 营养建议页面 UI
- [ ] 本地推送通知（医疗到期提醒）
- [ ] 体重趋势折线图（fl_chart）
- [ ] 时光轴照片上传功能

### v2.0 — 扩展功能
- [ ] Android 版本（Flutter 复用，零额外后端成本）
- [ ] 多宠物管理
- [ ] 健康报告 PDF 导出
- [ ] AI 营养计划个性化定制
- [ ] 宠物用药提醒与记录

---

## 贡献指南

```bash
# 1. Fork 本仓库并克隆到本地
git clone https://github.com/your-username/pet-health-app.git

# 2. 创建功能分支
git checkout -b feature/your-feature-name

# 3. 开发并提交（遵循 Conventional Commits）
git commit -m "feat(app): add weight trend chart"
git commit -m "fix(backend): handle Claude API timeout"
git commit -m "docs: update deployment guide"

# 4. Push 并创建 Pull Request
git push origin feature/your-feature-name
```

**Commit 类型规范：**

| 类型 | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(app): add photo upload` |
| `fix` | Bug 修复 | `fix(backend): handle null pet_id` |
| `chore` | 构建/配置/依赖变更 | `chore: upgrade flutter to 3.20` |
| `docs` | 文档更新 | `docs: add API examples` |
| `refactor` | 代码重构（不影响功能） | `refactor(app): extract pet card widget` |
| `test` | 测试相关 | `test(backend): add nutrition route tests` |

---

## License

MIT © 2026 [xiao222xian](https://github.com/xiao222xian)
