# Pet Soul H5 · 永久部署指南（100+ 人）

这是**纯静态 HTML**（无后端、数据在浏览器 `sessionStorage`），免费托管完全够 **100～1000 人**同时浏览。

| 方案 | 带宽 | 澳门访问 | 推荐 |
|------|------|----------|------|
| **Cloudflare Pages** | 免费不限量 | 很好 | ⭐ 长期首选（见 PROJECT.md） |
| **GitHub Pages** | 约 100GB/月 | 可以 | ⭐ 已有 GitHub 仓库时最快 |
| **Netlify** | 约 100GB/月 | 可以 | 拖文件夹即可 |

部署目录固定为：**`petsoul_h5/mock/`**（不是整个 `petsoul_h5`）。

**AI 文案（方案 B）**：魔搭 Studio BFF 在 `petsoul_h5/studio/`，H5 通过 `mock/js/ms-config.js` 配置 BFF 地址。未配置时自动用静态兜底文案。

---

## 方案 A · GitHub Pages（约 5 分钟）

仓库里已准备好 workflow：`.github/workflows/petsoul-h5-pages.yml`

### 1. 推送代码

```bash
cd /Users/admin/developer/pet
git add petsoul_h5/ .github/workflows/petsoul-h5-pages.yml
git commit -m "chore: add Pet Soul H5 mock and GitHub Pages deploy"
git push origin main
```

### 2. 在 GitHub 开启 Pages

1. 打开 https://github.com/xiao222xian/pet-health-app/settings/pages  
2. **Build and deployment → Source** 选 **Deploy from a branch**  
3. **Branch** 选 **`gh-pages`**，文件夹选 **`/ (root)`** → Save  
4. 打开 **Actions** → **Deploy Pet Soul H5** → **Run workflow**  
5. 绿勾后访问（约 1～2 分钟）：

> 若你之前试过 **GitHub Actions** 作为 Source 且 workflow 报红，改回上面这套 **gh-pages 分支** 即可。

```
https://xiao222xian.github.io/pet-health-app/
```

（若 404，等 1～2 分钟或看 Actions 日志）

### 3. 发给团队

| 用途 | 链接 |
|------|------|
| 屏索引 / 演示说明 | `https://xiao222xian.github.io/pet-health-app/index.html` |
| 直接建档开玩 | `https://xiao222xian.github.io/pet-health-app/profile.html` |

**演示路径：** profile → 测验 → 选意图 → Discover → ♥ Bella → 开聊

### 4. 以后更新

改 `petsoul_h5/mock/` 里任意文件 → `git push` → 约 1 分钟自动更新。

---

## 方案 B · Cloudflare Pages（推荐长期，带宽不限）

适合 hackathon 现场 100 人扫二维码，不怕流量爆。

### 1. 登录

https://dash.cloudflare.com → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**

### 2. 选仓库

连接 `xiao222xian/pet-health-app`（需先 push 含 `petsoul_h5` 的代码）

### 3. 构建设置

| 项 | 值 |
|----|-----|
| Production branch | `main` |
| Framework preset | **None** |
| Build command | （留空） |
| Build output directory | **`petsoul_h5/mock`** |

### 4. Deploy

完成后得到：`https://pet-soul-h5.pages.dev`（可在 Settings 改项目名）

### 5. 自定义域名（可选）

Pages → **Custom domains** → 绑定如 `demo.petsoul.app`

---

## 方案 C · Netlify Drop（不绑 Git，2 分钟）

1. 打开 https://app.netlify.com/drop  
2. 拖入本机文件夹 **`petsoul_h5/mock`**  
3. 得到 `https://随机名.netlify.app`  
4. Site settings → **Change site name** 改成好记的名字，如 `petsoul-h5-demo`

适合临时活动；长期仍建议 A 或 B（push 即更新）。

---

## 给 100 人用的注意事项

1. **入口链接** — 发 `…/profile.html` 或 `…/index.html`（索引页有演示说明）  
2. **微信** — 可能拦截外链，文案写「复制链接到 Safari / Chrome 打开」  
3. **手机** — 已是 H5 布局，竖屏体验最佳  
4. **数据** — 每人浏览器独立，刷新/换机要重新建档，**不会串数据**  
5. **图片** — 使用 Unsplash CDN，现场需有网络  
6. **并发** — 静态站无服务器压力；100 人同时刷只是 CDN 读文件，免费档足够  

---

## 本地预览（部署前自测）

```bash
cd petsoul_h5/mock
./deploy.sh serve
# 浏览器打开 http://localhost:8765/index.html
```

---

## 故障排查

| 现象 | 处理 |
|------|------|
| GitHub Pages 404 | Settings → Pages 是否选了 **GitHub Actions**；Actions 是否成功 |
| 样式/JS 丢失 | 确认部署根目录是 **`petsoul_h5/mock`**，不是仓库根目录 |
| 微信打不开 | 换系统浏览器；或绑自定义域名 |
| 想换入口域名 | Cloudflare / Netlify 绑自己的域名 |
