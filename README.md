# claude-tts

Text-to-speech plugin for Claude Code. Automatically speaks Claude's responses aloud using your choice of TTS provider, with local system TTS as a universal fallback.

## Supported Providers

| Provider | Quality | Cost | Requirements |
|----------|---------|------|-------------|
| **ElevenLabs** | Excellent | Paid | API key |
| **OpenAI** | Very good | Paid | API key |
| **Google Cloud** | Very good | Paid (free tier available) | API key |
| **Amazon Polly** | Good | Paid (free tier available) | AWS CLI configured |
| **Azure Speech** | Very good | Paid (free tier available) | API key + region |
| **Edge TTS** | Very good | Free | `pip install edge-tts` |
| **Kitten TTS** | Good | Free | `pip install KittenTTS soundfile` + `espeak` |
| **Local TTS** | Basic | Free | Built-in (see below) |

## Requirements

- **macOS**, **Linux**, or **Windows** (Git Bash / WSL)
- `jq` (see [jq downloads](https://jqlang.github.io/jq/download/))
- An audio player:
  - macOS: `afplay` (built-in)
  - Linux: `mpv`, `ffplay`, `paplay`, or `aplay`
  - Windows: PowerShell (built-in)

## Install

### From the marketplace

```
claude plugin install claude-tts
```

### Manual install

```bash
git clone https://github.com/MatiousCorp/claude-tts.git ~/.claude/plugins/claude-tts
```

Restart Claude Code after installing.

## Setup

```
/claude-tts:tts-setup <provider> <api-key>
```

### Examples

```
/claude-tts:tts-setup elevenlabs sk_abc123
/claude-tts:tts-setup openai sk-abc123
/claude-tts:tts-setup google AIza...
/claude-tts:tts-setup amazon
/claude-tts:tts-setup azure your-key-here
/claude-tts:tts-setup edge
/claude-tts:tts-setup kitten
/claude-tts:tts-setup local
```

### Provider details

| Provider | Default voice | Default model | Auth |
|----------|---------------|---------------|------|
| elevenlabs | Rachel (`21m00Tcm4TlvDq8ikWAM`) | `eleven_flash_v2_5` | `xi-api-key` header |
| openai | `alloy` | `tts-1` | `Bearer` token |
| google | `en-US-Neural2-F` | n/a | `X-Goog-Api-Key` header |
| amazon | `Joanna` | `neural` | AWS CLI env creds |
| azure | `en-US-JennyNeural` | n/a | `Ocp-Apim-Subscription-Key` header |
| edge | `en-US-AriaNeural` | n/a | none (free) |
| kitten | `expr-voice-2-f` | n/a | none (free, local) |
| local | system default | n/a | none |

### Without an API key

The plugin works without any API key:

- **Edge TTS**: High-quality neural voices via `edge-tts` (`pip install edge-tts`)
- **Kitten TTS**: Lightweight open-source model (under 25MB, CPU-only) with 8 expressive voices (`pip install KittenTTS soundfile`, plus `espeak` system dep). Requires Python 3.9+
- **Local TTS**: System built-in — macOS `say`, Linux `espeak-ng`/`espeak`/`piper`, Windows PowerShell SAPI

## Usage

Once set up, TTS works automatically. Every time Claude finishes a response, the text is cleaned and spoken aloud.

### Stopping playback

Audio stops automatically in several ways:

- **Press ESC** while Claude is generating — stops current audio and speaks the new response
- **Submit a new prompt** — any currently playing audio stops immediately
- **Run `/claude-tts:tts-stop`** — stop audio on demand without disabling TTS

### Commands

| Command | Description |
|---------|-------------|
| `/claude-tts:tts-on` | Enable TTS |
| `/claude-tts:tts-off` | Disable TTS |
| `/claude-tts:tts-stop` | Stop current audio playback |
| `/claude-tts:tts-status` | Show current status and provider |
| `/claude-tts:tts-setup <provider> [key]` | Configure TTS provider |

## Configuration

Config is stored in `~/.claude/claude-tts.local.md`:

```yaml
---
provider: "elevenlabs"
api_key: "sk_..."
voice_id: "21m00Tcm4TlvDq8ikWAM"
model_id: "eleven_flash_v2_5"
---
```

Only `provider` is required. Each provider has sensible defaults for `voice_id` and `model_id`.

For Azure, add `region`:

```yaml
---
provider: "azure"
api_key: "your-key"
region: "eastus"
---
```

### Environment variables

- `CLAUDE_TTS_API_KEY` — generic, works with any provider
- `ELEVENLABS_API_KEY` — legacy fallback for ElevenLabs provider

### Migration from v1

If your config has `elevenlabs_api_key:` but no `provider:`, it will automatically be treated as ElevenLabs. No action needed.

### Migration from v2 (say → local)

If your config has `provider: "say"`, it will automatically be mapped to `local`. No action needed.

## How it works

1. Claude finishes a response (Stop hook fires)
2. Any previously playing audio is stopped immediately
3. Text is cleaned: code blocks, URLs, file paths, and markdown formatting are stripped
4. A background worker sends the text to your configured provider
5. If the provider fails, local system TTS is used as fallback
6. Audio files are queued and played sequentially via the platform audio player

A `UserPromptSubmit` hook also runs on every new prompt, stopping any in-progress playback so audio never talks over your next interaction.

The hooks exit immediately so Claude Code is never blocked.

## Troubleshooting

**No audio playing**
1. Run `/claude-tts:tts-status` to check configuration
2. Make sure `jq` is installed (see [jq downloads](https://jqlang.github.io/jq/download/))
3. Check that `~/.claude/tts-enabled` exists

**Provider errors**
- Verify your API key and provider settings
- Check your usage quota with the provider
- The plugin falls back to local TTS automatically on API errors

**Audio queue stuck**
- Run `/claude-tts:tts-stop` to kill the daemon and clear the queue
- Or manually: `kill $(cat ${TMPDIR}/claude_tts_queue/daemon.pid) && rm -f ${TMPDIR}/claude_tts_queue/*.mp3 ${TMPDIR}/claude_tts_queue/*.wav`

**Linux: No audio player**
- Install one: `sudo apt install mpv` (or `ffmpeg` for ffplay, `pulseaudio-utils` for paplay)

**Linux: No local TTS**
- Install espeak-ng: `sudo apt install espeak-ng`

**Windows (Git Bash / WSL)**
- PowerShell must be available as `powershell.exe`
- WSL users: audio playback requires PulseAudio or PipeWire bridge to Windows

## License

MIT
