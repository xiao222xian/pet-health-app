# 匹配机制 · MATCH_SPEC

> 测验映射 **人宠相处风格**；合频本质是 **主人 Soul 匹配**，狗玩伴为辅助约束。

---

## 1. 公式

```text
合频% = 0.55 × 主人 Soul + 0.35 × 狗玩伴 + 0.10 × 意图加成
范围 clamp：52–98
```

| 层 | 来源 | 说明 |
|----|------|------|
| **主人 Soul** | 16 题 → `ownerSoul` 四维向量 | 社交/依恋/玩风/能量 |
| **狗玩伴** | 同向量加权 + 品种体型 | Petch 玩风 + 体型差 |
| **意图** | 遛狗搭子 / 都可 / 交友向 | 一致 +10，冲突 -5 |

Discover 卡显示 **一个合频数字**；Match 弹层拆开展示两行。

---

## 2. 测验 → 向量

每题 4 选项映射 `[social, bond, play, energy]` 增量，见 `mock/js/match-engine.js` → `OPTION_DELTAS`。

测完写入 profile：

```json
{
  "quizAnswers": [1, 2, 0, ...],
  "ownerSoul": { "social": 0.82, "bond": 0.78, "play": 0.75, "energy": 0.8 },
  "dogPlay": { "social": 0.85, "play": 0.8, "energy": 0.82 },
  "personaCode": "ENFP",
  "personaTitle": "社交小太陽"
}
```

**文案**：娱乐向 · 由你与牠的相处方式映射 · 非学术犬行为评估。

---

## 3. 性别与意图（门控）

| 意图 | 性别字段 |
|------|---------|
| 遛狗搭子 | 可选填，**不参与**过滤 |
| 都可 | 可选，弱参与 |
| 交友向 | 建议填 `ownerGender` + `lookingFor` |

`lookingFor`：不限 / 同性家長 / 異性家長

**硬过滤**：仅当任一方意图为「交友向」且双方均设置了偏好时，不满足则不出池。

Discover **不展示性别**；Match / 揭曉后可见。

---

## 4. 实现文件

| 文件 | 职责 |
|------|------|
| `mock/js/match-engine.js` | 计分、性别过滤、copy 文案 |
| `mock/js/profile.js` | sessionStorage 读写 |
| `mock/quiz.html` | 收集 answers → scoreQuizAnswers |
| `mock/discover.html` | 动态合频 % + 双层 why |

---

*2026-05-24 · v1*
