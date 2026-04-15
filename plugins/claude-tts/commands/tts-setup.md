---
description: Set up TTS with a provider (elevenlabs, openai, google, amazon, azure, edge, kitten, tada, fish, gemini, local)
allowed-tools: [Bash]
argument-hint: <provider> <api-key>
---

You MUST run this exact command and nothing else:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tts-setup.sh" $ARGUMENTS
```

If $ARGUMENTS is empty, tell the user:

**Usage:** `/claude-tts:tts-setup <provider> <api-key>`

**Providers:**
- `elevenlabs` — ElevenLabs TTS (high quality)
- `openai` — OpenAI TTS
- `google` — Google Cloud Text-to-Speech
- `amazon` — Amazon Polly (uses AWS CLI creds, no key needed)
- `azure` — Azure Cognitive Services Speech
- `edge` — Microsoft Edge TTS (free, no key needed)
- `kitten` — Kitten TTS V0.8 (free, local, no key needed)
- `tada` — Hume TADA (open-source, GPU recommended, optional voice cloning)
- `fish` — Fish Audio TTS (high quality, multilingual, voice cloning)
- `gemini` — Google Gemini 3.1 Flash TTS (70+ languages, multi-speaker)
- `local` — System built-in TTS (macOS say / espeak / Windows SAPI)

**Examples:**
- `/claude-tts:tts-setup elevenlabs sk_abc123`
- `/claude-tts:tts-setup openai sk-abc123`
- `/claude-tts:tts-setup edge`
- `/claude-tts:tts-setup kitten`
- `/claude-tts:tts-setup tada`
- `/claude-tts:tts-setup local`

Do NOT run any other scripts. Do NOT invent script names. Only run tts-setup.sh.
