# Pet Soul · 魔搭 Studio BFF（方案 B）

H5 前端（GitHub Pages）只调这个 BFF；**魔搭 API Token 只放在 Studio 环境变量**，不进 Git。

## 接口

| 方法 | 路径 | 用途 |
|------|------|------|
| GET | `/health` | 健康检查 |
| POST | `/api/soul-result` | 测验揭晓文案 |
| POST | `/api/match-blurb` | Match 合频解释 |
| POST | `/api/icebreaker` | 现场破冰话术 |

未配置 `MS_TOKEN` 时，接口仍可用，返回静态兜底文案（`ai: false`）。

## 部署到魔搭创空间

1. 注册 [魔搭](https://modelscope.cn)，绑定阿里云  
2. 个人中心 → **访问令牌** → 复制 Token  
3. [创空间](https://modelscope.cn/studios) → **创建** → 选 **自定义应用 / Docker**（支持 Python 即可）  
4. 上传本目录文件：`app.py`、`requirements.txt`  
5. **环境变量**（Studio 设置里添加）：

   | 变量 | 值 |
   |------|-----|
   | `MS_TOKEN` | 你的魔搭 API Token |
   | `MS_MODEL` | （可选）如 `Qwen/Qwen2.5-7B-Instruct` |

6. 启动命令（若需手动填）：

   ```bash
   pip install -r requirements.txt && python app.py
   ```

7. 发布完成后记 **运行域名**（规律：`https://{owner}-{英文名}.ms.show`）：

   ```
   https://xiao2xian222-petsoul-bff.ms.show
   ```

## 接回 H5

编辑 `mock/js/ms-config.js`：

```javascript
window.PETSOUL_BFF_URL = 'https://xiao2xian222-petsoul-bff.ms.show';
```

**不要用** `https://www.modelscope.cn/studios/...` —— 那是介绍页，API 会返回 HTML。

留空则全部使用页面原有静态文案，不影响演示。

## 本地调试

```bash
cd petsoul_h5/studio
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export MS_TOKEN=你的token   # 可选
python app.py
# http://127.0.0.1:7860/health
```

本地测 H5 时可在浏览器控制台执行：

```javascript
localStorage.setItem('petsoul_bff_url', 'http://127.0.0.1:7860');
location.reload();
```

## 额度

魔搭 Inference API 约 **2000 次/天**（全模型共享）。Hackathon 100 人量级足够；可在 BFF 前再加 nginx/Studio 限流（后续）。
