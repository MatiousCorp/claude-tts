---
description: Set up TTS plugin with your ElevenLabs API key
allowed-tools: [Bash]
---

Run the setup script with the provided arguments:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tts-setup.sh" $ARGUMENTS
```

If no API key argument was provided, tell the user:
"Please provide your ElevenLabs API key: `/claude-tts:tts-setup sk_your_key_here`"

After setup completes, report the results to the user.
