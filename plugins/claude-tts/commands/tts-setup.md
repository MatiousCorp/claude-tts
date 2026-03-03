---
description: Set up TTS with a provider (elevenlabs, openai, google, amazon, azure, say)
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
- `say` — macOS built-in (free, no key needed)

**Examples:**
- `/claude-tts:tts-setup elevenlabs sk_abc123`
- `/claude-tts:tts-setup openai sk-abc123`
- `/claude-tts:tts-setup say`

Do NOT run any other scripts. Do NOT invent script names. Only run tts-setup.sh.
