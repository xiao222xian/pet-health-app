# AGENT.md

本文件面向在本仓库内工作的代码代理、自动化协作者和新接手的工程师。目标是让协作者在不依赖口头上下文的情况下，快速理解项目结构、真实运行方式、部署链路、当前约束和常见陷阱。

---

## 1. 项目概览

这是一个宠物健康管理与宠物商业化工作区。当前主体由多个相互独立的业务/技术板块组成：

- `app/`: Flutter 客户端，当前以 iOS 为主
- `backend/`: Node.js + TypeScript API 服务，部署在自有 VPS `/opt/pet-backend`
- `supabase/`: PostgreSQL 迁移、Auth、Storage 相关定义
- `commerce/`: 宠物电商与现金流实验，当前包含海外宠物保健品 storefront 原型
- `硬件/`: 宠物机器人、智能小车和硬件合作相关资料
- `petsoul_h5/`: H5、mock、studio 和相关实验材料

核心功能：

- 宠物档案
- 医疗记录
- 健康日志
- 生命时光轴
- AI 辅助问诊

长期新增方向：

- 宠物保健品/营养品电商现金流验证
- 宠物机器人/实体 AI 原型
- 宠物健康 App、电商和硬件的长期生态整合

当前线上形态是：

- 客户端本地运行或打包成 iOS App
- 业务数据主要直接访问 Supabase
- AI 问诊通过 `backend/` 代理调用外部模型服务

---

## 2. 真实代码状态与 README 差异

仓库中的 `README.md` 有价值，但**不是完全可信的当前真相**。协作者应以实际代码为准。

当前已确认的关键差异：

- README 仍然描述了旧的 Anthropic/Claude 方案
- 实际问诊服务已拆到 `backend/src/consult/`，模型供应商整合仍在 `backend/src/services/claude.ts`
- 当前 AI 主通道是 FLU/OpenAI-compatible `gpt-5.5`，并保留 Gemini/OpenRouter/Groq 等回退和规则兜底
- README 中的数据库类型描述存在旧值；实际前端已做了一部分新旧约束兼容

工作原则：

- 涉及 AI、部署、数据库约束、支付、路由时，优先读代码，不要直接复述 README

---

## 3. 顶层目录说明

### 仓库根目录

- `README.md`: 项目总说明，部分过时
- `LICENSE`: MIT
- `.env`: 本地环境变量，**不要提交**
- `.env.example`: 环境变量模板
- `.claude/`: 本地代理配置，默认不应进入发布提交
- `docs/`: 部署和设计文档
- `shared/`: 目前仓库级共享目录，使用很少
- `logo.png`: 设计素材
- `PROJECT_STRUCTURE.md`: 当前多板块结构说明
- `commerce/`: 电商业务板块。第一阶段面向海外宠物保健品 storefront，不接 AI App/机器人叙事
- `硬件/`: 宠物机器人与硬件资料
- `petsoul_h5/`: H5/花与兽/相关实验，含 nested repo 和生成缓存，广泛 staging 前必须分类

### `app/`

Flutter 客户端代码。当前活跃代码集中在：

- `app/lib/app/`
- `app/lib/features/`
- `app/lib/shared/`

注意：

- `app/run.sh` 读取本地配置并默认使用线上 HTTPS API：`https://pet.superstar.tots.asia/api/v1`
- `app/web/` 和 `app/build/web/` 存在构建产物或静态输出，不代表主要发布目标

### `backend/`

Node API 服务：

- `src/index.ts`: 服务入口
- `src/routes/consult.ts`: AI 问诊接口，包含普通 JSON 与 SSE streaming 入口
- `src/consult/`: 问诊 contract、intent、risk rules、state store、agent orchestration、SSE helper
- `src/routes/auth.ts`: 后端注册入口
- `src/routes/pets.ts`: 后端宠物创建入口
- `src/routes/nutrition.ts`: 营养建议接口
- `src/services/claude.ts`: 当前 AI 供应商整合入口
- `src/middleware/auth.ts`: JWT 认证中间件

### `supabase/`

- `migrations/`: 数据库迁移文件

这是线上数据结构的真实来源之一。前端新功能如果依赖字段或约束修改，必须同步检查这里。

---

## 4. 客户端架构

### 4.1 路由

路由文件：

- `app/lib/app/router.dart`

当前使用 `GoRouter`，并通过 `Supabase.instance.client.auth.onAuthStateChange` 刷新 redirect。

登录态规则：

- 未登录访问任何非 `/auth` 路由，会被重定向到 `/auth`
- 已登录访问 `/auth`，会被重定向到 `/`

主结构是 `StatefulShellRoute.indexedStack`，分成 5 个 Tab：

- `/` 档案
- `/health` 健康
- `/consult` 问诊
- `/timeline` 时光轴
- `/account` 我的

### 4.2 数据访问模式

客户端有两类数据访问：

1. 直接走 Supabase SDK
   - 宠物
   - 医疗记录
   - 健康日志
   - 时光轴
   - 个人资料

2. 走后端 HTTP API
   - AI 问诊
   - 营养建议

不要把两者混淆。界面变了但模型没变，通常是后端未部署；界面保存报约束错，通常是 Supabase 迁移未同步。

### 4.3 共享服务

关键文件：

- `app/lib/shared/services/supabase_service.dart`
- `app/lib/shared/services/api_service.dart`

`SupabaseService` 当前除基础客户端封装外，还承担本地刷新信号：

- `dataVersion`
- `profileVersion`

很多页面依赖这些 `ValueNotifier` 触发刷新。修改跨页数据后，如果 UI 没刷新，先检查是否有调用：

- `SupabaseService.notifyDataChanged()`
- `SupabaseService.notifyProfileChanged()`

### 4.4 当前活跃功能模块

- `features/auth/`
- `features/profile/`
- `features/health_log/`
- `features/timeline/`
- `features/consult/`
- `features/account/`

这些模块之间共享状态很少，更多是通过 Supabase 和 `notifyDataChanged()` 解耦。

---

## 5. 后端架构

### 5.1 服务入口

文件：

- `backend/src/index.ts`

当前暴露的主要 API：

- `POST /api/v1/consult`
- `POST /api/v1/nutrition`

### 5.2 问诊链路

核心文件：

- `backend/src/routes/consult.ts`
- `backend/src/services/claude.ts`

当前问诊模型链路，按代码真实顺序：

1. FLU/OpenAI-compatible
   - 生产主链路
   - 当前模型：`gpt-5.5`
   - 环境变量：`FLU_BASE_URL`、`FLU_MODEL`、`FLU_API_KEY`
2. Gemini/OpenRouter/Groq 等历史回退链路
3. 保守规则兜底
   - 模型供应商失败或返回非法 JSON 时，足够明确的症状仍会得到安全分诊建议

这不是 Claude 主链路。不要把真实 API key 写入仓库。

### 5.3 问诊输出结构

当前后端已将问诊响应升级为结构化输出，字段包括：

- `risk_level`
- `summary`
- `possible_causes`
- `home_care`
- `watch_points`
- `when_to_seek_vet`
- `follow_up_question`
- `advice`
- `seek_vet`
- `disclaimer`

如果修改问诊体验，前后端要一起改：

- 后端 JSON schema
- 前端展示组件
- 历史记录详情页
- 结束问诊综合建议卡

### 5.4 认证

所有问诊/营养接口都依赖 Supabase JWT 认证。

原则：

- 客户端把 access token 放到 `Authorization: Bearer ...`
- 后端先校验 token，再继续读数据库和调用模型

---

## 6. 数据库与 Supabase

### 6.1 真实数据平面

本项目的主要线上状态来自 Supabase：

- Auth
- PostgreSQL
- Storage

### 6.2 重要迁移

除最初的 001~007 外，当前还要特别注意后续迁移：

- `009_fix_medical_records_types.sql`
- `010_add_growth_type.sql`
- `011_add_medical_assets_fields.sql`
- `012_create_storage_buckets.sql`

如果线上库没跑这些迁移，会出现典型问题：

- `medical_records_type_check` 约束报错
- `timeline_events_type_check` 约束报错
- 新字段保存失败
- 图片 bucket 不存在

### 6.3 约束兼容现状

前端目前已经做了部分“新 UI -> 旧库值”的兼容：

- 医疗记录：
  - UI 使用 `surgery` / `other`
  - 部分场景编码映射到旧值兼容线上库
- 时光轴：
  - UI 使用 `growth`
  - 部分场景编码映射到旧值兼容线上库

这说明：

- 线上 Supabase 不一定和本地迁移完全同步
- 修改相关类型时，必须同时评估：
  - 前端展示值
  - 前端提交值
  - 线上实际数据库约束

### 6.4 Storage bucket

当前代码依赖这些 bucket：

- `pet-avatars`
- `profile-avatars`
- `medical-records`
- `timeline-photos`

部分头像逻辑已经改成直接存数据库 data URL，不再完全依赖 bucket，但医疗图和时光轴图仍依赖 Storage。

---

## 7. AI 与业务逻辑的当前实现重点

### 7.1 问诊页

文件：

- `app/lib/features/consult/consult_screen.dart`

当前实现特点：

- 首次进入有免责声明页
- 支持多轮问诊
- 支持图片上传
- 支持切换宠物
- 支持结束问诊生成综合建议
- 历史记录可查看

已知重要实现细节：

- 结构化问诊卡片展示已经落地
- 宠物切换时会清空当前对话态，避免跨宠物串内容
- `SafeArea(bottom: false)` 等布局修正确保输入区表现合理

### 7.2 档案页提醒逻辑

文件：

- `app/lib/features/profile/pet_profile_screen.dart`

当前提醒逻辑已经从“仅取未来 30 天”改为：

- 只要 `medical_records.next_due_date` 不为空，就参与提醒
- 优先显示已逾期记录
- 否则显示最近一个未来提醒

如果线上仍显示 `-`，优先排查：

1. 该宠物是否真的有 `next_due_date`
2. 是否数据写到当前选中的宠物
3. 线上 Supabase 表是否保存成功

### 7.3 时光轴图片

文件：

- `app/lib/features/timeline/event_form_screen.dart`
- `app/lib/features/timeline/timeline_screen.dart`

当前已支持：

- 里程碑/成长点滴上传多张图片
- 表单缩略图可点开预览
- 详情页图片可全屏查看
- 列表卡片会显示图片缩略图

---

## 8. 本地开发

### 8.1 目录

当前本地真实工作目录是：

`/Users/admin/developer/pet`

不要假设还是旧的中文目录路径。

### 8.2 Flutter 运行

常用方式：

```bash
cd /Users/admin/developer/pet/app
./run.sh
```

`run.sh` 当前会注入：

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `API_BASE_URL=https://pet.superstar.tots.asia/api/v1`

含义：

- 你本地跑起来的 Flutter 页面，默认打的是**线上 HTTPS API**
- 不是本地 Node 服务

这很关键。UI 是本地，AI 问诊和部分后端逻辑可能仍是线上。

### 8.3 后端运行

常用方式：

```bash
cd backend
npm install
npm run dev
```

构建：

```bash
npm run build
```

### 8.4 常用检查

Flutter：

```bash
cd app
flutter analyze
```

Backend：

```bash
cd backend
npm run build
```

---

## 9. 部署链路

### 9.1 GitHub

主分支：

- `main`

远端：

- `origin https://github.com/xiao222xian/pet-health-app.git`

当前团队操作方式偏向直接推 `main`，没有看到复杂 release 分支流。

### 9.2 VPS / nginx / systemd

后端部署在自有 VPS：

- 域名：`https://pet.superstar.tots.asia`
- 服务器：`103.189.141.67`
- 代码目录：`/opt/pet-backend`
- 进程：systemd `pet-backend`
- 反代：nginx HTTPS -> `127.0.0.1:3000`
- 状态：Redis `redis://127.0.0.1:6379`

Build / Start 参考：

- Build: `npm run build`
- Start: `node dist/index.js`

环境变量至少应包括：

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OPENROUTER_API_KEY`
- `OPENROUTER_MODEL`
- `GROQ_API_KEY`
- `GROQ_MODEL`
- `GEMINI_API_KEY`
- `GEMINI_MODEL`

`docs/DEPLOYMENT.md` 仍提 Anthropic，属旧文档。

### 9.3 Supabase

Git push 不会自动更新数据库结构。上线功能时必须单独检查：

- 迁移是否跑完
- bucket 是否存在
- RLS 是否仍然兼容

### 9.4 iOS 包

如果只是本地验证：

- `flutter run`

如果正式上线：

- `flutter build ios` 或 Xcode Archive
- 上传 App Store Connect / TestFlight

---

## 10. 支付与商业化背景

项目讨论过 App Store 支付方案。当前结论应理解为：

- 持续 AI / 云服务更适合订阅
- 一次性永久解锁适合非消耗型内购
- AI 次数包适合消耗型内购
- “买一次，一年有效，不自动续费”适合非续期订阅

如果未来代理需要改支付逻辑，不要把支付类型混用。

---

## 11. 提交与发布约束

### 11.1 不要提交的内容

默认不应提交：

- `.env`
- `backend/.env`
- `.claude/settings.local.json`
- 其他本地机密或编辑器私有配置

### 11.2 已知仓库现状

仓库中存在部分构建产物和 `dist/`、`build/`、`web/` 等内容。不要假设仓库是极简源码仓。

做提交前要先判断：

- 这是业务源码
- 还是生成文件
- 是否真的需要发布

### 11.3 典型提交流程

```bash
cd /Users/admin/developer/pet
git status --short
git add <明确需要的文件>
git commit -m "..."
git push origin main
```

不要无差别提交本地配置。

---

## 12. 常见问题与排查路径

### 12.1 “本地改了，线上没变”

优先检查：

1. 是否已经 `git push`
2. 是否已同步到 `/opt/pet-backend` 并重启 `pet-backend`
3. App 是否仍打旧 API 地址

### 12.2 “UI 变了，但保存时报数据库约束错”

优先检查：

1. Supabase 迁移是否执行
2. 类型值与线上约束是否一致
3. 是否需要前端兼容映射

### 12.3 “问诊表现不像本地代码”

优先检查：

1. VPS `/opt/pet-backend` 是否部署了新代码并重启
2. 线上环境变量模型配置
3. App 打的是哪个 `API_BASE_URL`

### 12.4 “退出登录/删除账号黑屏”

该问题曾由“只改 auth 状态、未主动路由跳转”导致。当前修复思路是：

- 成功后显式 `context.go('/auth')`

涉及账户页行为时，优先检查这一路由策略是否被回退。

### 12.5 “宠物切换后问诊黑屏”

该问题曾由宠物选择弹层错误使用页面 `context` 导致。类似场景应注意：

- 弹层关闭使用弹层自己的 `BuildContext`
- 切宠物时清理上下文态

---

## 13. 建议代理的工作方式

在这个仓库里工作，推荐遵循以下顺序：

1. 先确认需求影响的是：
   - Flutter 本地页面
   - 线上后端
   - Supabase 结构
   - 还是三者联动
2. 修改前先查真实代码，不以 README 为准
3. 改完最少做：
   - Flutter `dart format`
   - `flutter analyze`（相关文件）
   - Backend `npm run build`（如改了后端）
4. 涉及跨页数据变更，检查是否触发 `notifyDataChanged`
5. 涉及类型枚举，检查：
   - Dart model
   - 提交 payload
   - 页面展示映射
   - Supabase 约束
6. 涉及部署相关问题，明确区分：
   - 本地代码
   - GitHub 远端
   - VPS/systemd/nginx 线上服务
   - Supabase 线上库

---

## 14. 当前最重要的维护事实

- 本地真实仓库路径：`/Users/admin/developer/pet`
- Git 主分支：`main`
- 线上 API 默认地址写在 `app/run.sh` / `app/lib/shared/services/api_service.dart`
- 问诊当前真实模型链路：FLU/OpenAI-compatible `gpt-5.5` -> 历史供应商回退 -> 规则兜底
- README 仍存在过时内容，部署文档以本文件和 `docs/CHEAP_DEPLOY.md` 为准
- 数据库迁移状态对线上功能影响很大，不能省略

---

## 15. Pet Soul（独立 H5 · 并行产品线）

与 `app/` 健康 App **并行验证**，不替代主产品。协作者必读：**`petsoul_h5/PROJECT.md`**。

| 项 | 内容 |
|----|------|
| 定位 | 宠物的 Soul — Petch 狗格 + FetchaDate WingPet + Soul 式 Tinder 滑很多狗 |
| 栈 | Vue 3 + Vite + TS · Supabase · **Cloudflare Pages**（澳门可用，无需 VPS） |
| 设计 | 乔布斯 + 苹果 + 喜茶 · **永远做减法**；准则见 `petsoul_h5/设计参考/04_业务文档设计规范/设计铁律.md` |
| Cursor 规则 | `.cursor/rules/petsoul.mdc`（编辑 `petsoul_h5/**` 时生效） |

Day 1 范围：测验 → 进池 → Discover 左右滑 → Like 弹层；不做 IM / App Store 首日。

---

## 16. 如果要继续扩展

后续高概率扩展方向：

- 更稳定的支付模型
- 宠物项圈硬件联动
- 设备表与设备事件表
- 订阅/次数包权限控制
- 更细的 AI 追问与健康分析

这类改动都会跨越：

- 客户端 UI
- Supabase schema
- 后端 API
- App Store 商业化配置

不要把它当成单点前端改动处理。
