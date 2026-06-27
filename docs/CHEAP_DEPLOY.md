# 低成本部署指南（$0/月起）

当前组合：

| 服务 | 方案 | 费用 | 用途 |
|------|------|------|------|
| Supabase | Free | $0 | 登录、数据库、Storage |
| 自有 VPS `103.189.141.67` | 包月 | — | Node 后端（AI 问诊/注册/宠物创建），常驻不休眠 |

> 2026-06-25：Node 后端已从 Render 免费版迁移到自有服务器。Render 免费版 15 分钟无请求会休眠，故弃用。
> 2026-06-26：`pet.superstar.tots.asia` 已接入 HTTPS，HTTP 自动跳转 HTTPS。

---

## 当前生产后端：自有服务器（2026-06-25 起）

Node 后端已从 Render 免费版迁移到自有 VPS，常驻运行不再休眠。

| 项 | 值 |
|----|----|
| 地址 | `https://pet.superstar.tots.asia` |
| 系统 | Ubuntu 22.04 · Node 20 · nginx HTTPS 反代 `127.0.0.1:3000` |
| 进程 | systemd 服务 `pet-backend`（`Restart=always`，开机自启） |
| 代码目录 | `/opt/pet-backend`（`.env` 同目录，dotenv 加载） |
| 状态存储 | Redis `redis://127.0.0.1:6379`（consult state） |
| 健康检查 | `curl https://pet.superstar.tots.asia/health` → `{"status":"ok"}` |

App 端：`app/config.local.sh` 和默认配置应把 `API_BASE_URL` 指向 `https://pet.superstar.tots.asia/api/v1`。

> 证书由 certbot 管理，续期定时器已存在。裸 IP HTTP 不是主要生产入口，浏览器访问根路径如果返回 404，表示 Express 没有 `GET /` 页面，不代表 API 不可用。

### 更新后端代码（重新部署）

```bash
# 1. 同步源码（排除 node_modules/dist/.git/.env）
rsync -az --delete \
  --exclude=node_modules --exclude=dist --exclude=.git --exclude=.env \
  -e ssh backend/ root@103.189.141.67:/opt/pet-backend/

# 2. 服务器上重建并重启
ssh root@103.189.141.67 'cd /opt/pet-backend && npm ci && npm run build && systemctl restart pet-backend'

# 3. 验证
curl https://pet.superstar.tots.asia/health
```

### 服务管理

```bash
systemctl status pet-backend      # 状态
systemctl restart pet-backend     # 重启
journalctl -u pet-backend -n 50   # 日志（也写到 /var/log/pet-backend.log）
```

修改 `/opt/pet-backend/.env`（密钥）后需 `systemctl restart pet-backend` 生效。

---

## 已完成（2026-05-27）

- 新建 Supabase 项目：`pet-health-app-v2`
- 项目 ID：`aktmdyxeqcmaldbylzfi`
- 区域：Tokyo（`ap-northeast-1`）
- 14 个数据库迁移已全部推送
- Flutter 客户端已切换到新 Supabase 地址

控制台：https://supabase.com/dashboard/project/aktmdyxeqcmaldbylzfi

---

## 旧方案：部署后端到 Render（已弃用）

1. 打开 https://dashboard.render.com → **New +** → **Blueprint**
2. 连接 GitHub 仓库 `xiao222xian/pet-health-app`
3. Render 会读取根目录的 `render.yaml` 自动创建服务
4. 在 Render Dashboard → **pet-health-backend** → **Environment**，填入：

```
SUPABASE_URL=https://aktmdyxeqcmaldbylzfi.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<从 Supabase Dashboard → Settings → API 复制>
GEMINI_API_KEY=<你的 Gemini Key>
OPENROUTER_API_KEY=<可选，回退用>
GROQ_API_KEY=<可选，回退用>
```

5. 部署完成后记下域名，例如：`https://pet-health-backend-xxxx.onrender.com`

验证：

```bash
curl https://pet-health-backend-xxxx.onrender.com/health
# 期望：{"status":"ok"}
```

---

## 第二步：更新 App 的后端地址

创建 `app/config.local.sh`：

```bash
cp app/config.example.sh app/config.local.sh
```

编辑 `app/config.local.sh`：

```bash
export SUPABASE_URL="https://aktmdyxeqcmaldbylzfi.supabase.co"
export SUPABASE_ANON_KEY="<anon key>"
export API_BASE_URL="https://pet.superstar.tots.asia/api/v1"
```

运行：

```bash
cd app && ./run.sh
```

---

## 本地开发（模拟器）

默认 `run.sh` 会把 AI 后端指向 `http://127.0.0.1:3000/api/v1`。

另开终端启动后端：

```bash
cd backend
npm install
npm run dev
```

真机调试时，`127.0.0.1` 不可用，优先使用 `https://pet.superstar.tots.asia/api/v1`。

---

## iOS 正式打包

```bash
cd app
flutter build ios \
  --dart-define=SUPABASE_URL=https://aktmdyxeqcmaldbylzfi.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key> \
  --dart-define=API_BASE_URL=https://pet.superstar.tots.asia/api/v1
```

---

## 旧服务说明

| 旧地址 | 状态 |
|--------|------|
| `srljyvqojhhwbgtdojkh.supabase.co` | 已暂停/失效，数据未迁移 |
| `stellar-passion-production-56af.up.railway.app` | Railway 应用已删除 |
| Render `pet-health-backend`（`render.yaml`） | 已被自有服务器替代（2026-06-25），可在 Render 控制台删除 |

旧项目里的用户数据**不会自动**进新项目。如需恢复，只能从旧 Supabase 备份导入。

---

## 费用升级路径

| 阶段 | 建议 |
|------|------|
| 开发/内测 | Supabase Free + 自有 VPS |
| 小范围 TestFlight | Supabase Free/Pro + 自有 VPS |
| 正式运营 | Supabase Pro + 自有 VPS + 监控/备份 |

---

## 常用命令

```bash
# 查看 Supabase 项目
supabase projects list

# 推送新迁移
supabase db push --linked

# 本地后端健康检查
curl http://localhost:3000/health
```
