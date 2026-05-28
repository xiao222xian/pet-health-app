# Pet Soul · Hackathon 自检清单

> 3 分钟演示前过一遍。降级：魔搭 BFF 不可用时仍走静态文案（`ai: false`）。

## 一句话定位

**让宠物替主人先认识同场的人** — 近场弱连接 + 缘分罗盘 + 宠物 Agent 破冰，不是宠物版 Tinder。

## 演示路径（约 3 分钟）

1. `entry.html` → 填档 `profile.html`
2. `quiz.html` → 16 题
3. `result.html` → AI 灵魂揭晓 + 选意图
4. `discover.html` → 滑卡 · Pass 有隐私 toast
5. ♥ Bella → **缘分罗盘** Match 弹层
6. `chat.html` → **Agent 建议 → 主人确认发送** · 临时会话不加微信

## 质量自检

| 检查项 | 状态 |
|--------|------|
| 主打 3 功能（罗盘 / Agent / 近场名片） | 叙事清晰，不堆功能 |
| AI 原生 | 魔搭 BFF：揭晓 / 合频 / 破冰 |
| 安全 | 双向 Match、同场模糊距离、Pass 无通知、临时会话 |
| 降级 | BFF 失败 → 静态兜底 |
| 叠字 | Discover 单卡 + 抽屉收起 hero |

## 命令

```bash
cd petsoul_h5/mock
node --test smoke.test.mjs
```

## 链接

- H5：https://xiao222xian.github.io/pet-health-app/entry.html
- BFF：https://xiao2xian222-petsoul-bff.ms.show/
