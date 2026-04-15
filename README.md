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
| **Fish Audio** | Excellent | Paid (billing required) | API key |
| **Gemini TTS** | Excellent | Paid (free tier available) | API key |
| **MiMo TTS** | Excellent | Free (limited time) | API key |
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
/claude-tts:tts-setup mimo your-key-here
/claude-tts:tts-setup fish your-key-here
/claude-tts:tts-setup gemini AIza...
/claude-tts:tts-setup tada
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
| mimo | `mimo_default` | `mimo-v2-tts` | `api-key` header |
| fish | (optional reference ID) | `s2-pro` | `Authorization: Bearer` token |
| gemini | `Kore` | `gemini-3.1-flash-tts-preview` | `x-goog-api-key` header |
| tada | reference WAV path | `tada-1b` | none (open-source) |
| local | system default | n/a | none |

### Without an API key

The plugin works without any API key:

- **Edge TTS**: High-quality neural voices via `edge-tts` (`pip install edge-tts`)
- **Kitten TTS**: Lightweight open-source model (under 25MB, CPU-only) with 8 expressive voices (`pip install KittenTTS soundfile`, plus `espeak` system dep). Requires Python 3.9+
- **TADA**: Hume AI's open-source voice cloning model (`pip install hume-tada`). Works out of the box; optionally provide a reference WAV to clone a specific voice. GPU recommended (CUDA or Apple MPS); CPU works but is slow. Models: `tada-1b` (English) or `tada-3b-ml` (multilingual)
- **Local TTS**: System built-in — macOS `say`, Linux `espeak-ng`/`espeak`/`piper`, Windows PowerShell SAPI

### With an API key (paid)

- **Fish Audio**: High-quality multilingual TTS with voice cloning support. Requires a paid account with billing enabled — there is no free tier. Optionally provide a reference voice ID to clone a specific voice. Get a key at [fish.audio](https://fish.audio/). Model: `s2-pro`

### With an API key (free tier)

- **Gemini TTS**: Google's Gemini 3.1 Flash TTS — 30 built-in voices, 70+ languages, multi-speaker dialogue, and audio tags for style control (`[whispers]`, `[laughs]`). Free tier available. Get a key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey). Models: `gemini-3.1-flash-tts-preview` (latest), `gemini-2.5-flash-preview-tts`, `gemini-2.5-pro-preview-tts`
- **MiMo TTS**: Xiaomi's MiMo-V2-TTS — highly expressive with contextual emotion awareness, style control, dialect support, and singing capability. Free during limited-time promotion. Get a key at [platform.xiaomimimo.com](https://platform.xiaomimimo.com/#/console/api-keys)

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
