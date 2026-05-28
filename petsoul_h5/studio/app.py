"""
Pet Soul · ModelScope Studio BFF
代理魔搭 Inference API，Token 仅存服务端环境变量 MS_TOKEN
"""
from __future__ import annotations

import os
from typing import Optional

import gradio as gr
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI
from pydantic import BaseModel, Field

fastapi_app = FastAPI(title="Pet Soul BFF", version="1.0.0")

fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

MS_TOKEN = os.environ.get("MS_TOKEN", "")
MS_MODEL = os.environ.get("MS_MODEL", "Qwen/Qwen2.5-7B-Instruct")
MS_BASE = os.environ.get("MS_BASE_URL", "https://api-inference.modelscope.cn/v1/")


def _client() -> Optional[OpenAI]:
    if not MS_TOKEN:
        return None
    return OpenAI(api_key=MS_TOKEN, base_url=MS_BASE)


def _chat(system: str, user: str, max_tokens: int = 160) -> Optional[str]:
    client = _client()
    if not client:
        return None
    try:
        resp = client.chat.completions.create(
            model=MS_MODEL,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            max_tokens=max_tokens,
            temperature=0.75,
        )
        text = (resp.choices[0].message.content or "").strip()
        return text or None
    except Exception:
        return None


SYSTEM = (
    "你是 Pet Soul 现场活动文案助手。"
    "用繁体中文，可带少量粤语口语。"
    "简洁温暖，不要 emoji，不要标题，不要列表符号。"
)


class SoulResultBody(BaseModel):
    petName: str = "豆包"
    breed: str = "柯基"
    personaCode: str = "ENFP"
    personaTitle: str = "社交小太陽"
    playArea: str = "同場"


class MatchBlurbBody(BaseModel):
    petName: str
    breed: str
    persona: str = ""
    score: int = Field(ge=0, le=100)
    ownerScore: int = Field(ge=0, le=100)
    dogScore: int = Field(ge=0, le=100)
    userIntent: str = "遛狗搭子"
    theirIntent: str = "都可"
    fallback: str = ""


class IcebreakerBody(BaseModel):
    userPetName: str = "豆包"
    theirPetName: str
    theirOwner: str = ""
    playArea: str = "同場"
    userIce: str = ""
    theirIce: str = ""
    fallback: str = ""


@fastapi_app.get("/api")
def root():
    return {
        "service": "Pet Soul BFF",
        "ai_ready": bool(MS_TOKEN),
        "model": MS_MODEL,
        "endpoints": ["/health", "/api/soul-result", "/api/match-blurb", "/api/icebreaker"],
    }


@fastapi_app.get("/health")
def health():
    return {"ok": True, "ai_ready": bool(MS_TOKEN)}


@fastapi_app.post("/api/soul-result")
def soul_result(body: SoulResultBody):
    fallback = (
        f"{body.petName} 是 {body.personaTitle} · "
        f"{body.personaCode} 映射你與牠的相处方式 · 已入池等合频。"
    )
    prompt = (
        f"宠物名叫{body.petName}，品种{body.breed}，"
        f"狗格 {body.personaCode} {body.personaTitle}，常在{body.playArea}。"
        "写2句灵魂鉴定揭晓文案，每句不超过22字。"
    )
    text = _chat(SYSTEM, prompt)
    return {"text": text or fallback, "ai": bool(text)}


@fastapi_app.post("/api/match-blurb")
def match_blurb(body: MatchBlurbBody):
    fallback = body.fallback or "雙向合頻 · 同場先见见再决定。"
    prompt = (
        f"合频 {body.score}%，主人 Soul {body.ownerScore}%，狗玩伴 {body.dogScore}%。"
        f"对方宠物 {body.petName}（{body.breed}，{body.persona}），"
        f"你的意图 {body.userIntent}，对方 {body.theirIntent}。"
        "写1句为什么合频，不超过28字。"
    )
    text = _chat(SYSTEM, prompt, max_tokens=80)
    return {"text": text or fallback, "ai": bool(text)}


@fastapi_app.post("/api/icebreaker")
def icebreaker(body: IcebreakerBody):
    fallback = body.fallback or f"同場 · 可以问 {body.theirPetName} 今日肯唔肯玩。"
    prompt = (
        f"现场破冰：你的宠 {body.userPetName}，对方 {body.theirPetName}。"
        f"对方主人线索：{body.theirIce or '无'}。"
        f"你的现场识别：{body.userIce or '无'}。"
        f"地点 {body.playArea}。"
        "写1句可直接说出口的开场白，不超过30字。"
    )
    text = _chat(SYSTEM, prompt, max_tokens=90)
    return {"text": text or fallback, "ai": bool(text)}


_ai_status = "已配置 MS_TOKEN，AI 文案可用" if MS_TOKEN else "未配置 MS_TOKEN，接口返回静态兜底文案"

with gr.Blocks(title="Pet Soul BFF", css=".gradio-container {max-width: 720px !important}") as demo:
    gr.Markdown(
        f"""# Pet Soul · AI 文案后端

**状态：** {_ai_status}

**模型：** `{MS_MODEL}`

H5 前端（GitHub Pages）通过以下 API 调用本服务：

| 接口 | 用途 |
|------|------|
| `GET /health` | 健康检查 |
| `POST /api/soul-result` | 灵魂鉴定揭晓 |
| `POST /api/match-blurb` | Match 合频解释 |
| `POST /api/icebreaker` | 现场破冰话术 |

在 Studio **环境变量** 中设置 `MS_TOKEN`（魔搭 API Token）后重新发布。
"""
    )

# 魔搭 Gradio SDK 识别 demo；API 路由挂在同一进程
app = gr.mount_gradio_app(fastapi_app, demo, path="/")

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=7860, reload=False)
