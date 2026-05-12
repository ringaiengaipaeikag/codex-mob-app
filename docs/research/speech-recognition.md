# Speech Recognition Research

Last updated: 2026-05-03

## Scope

This research covers voice input only:

```text
microphone button -> record voice -> transcribe -> insert text into Message -> user sends to Codex
```

Voice commands and hands-free control are explicitly out of scope for the first
implementation.

## Decision

Recommended MVP:

- Browser records a short push-to-talk clip with `getUserMedia` and
  `MediaRecorder`.
- The mobile UI uploads that clip to the local gateway.
- The gateway sends the audio to OpenAI `/v1/audio/transcriptions` using
  `gpt-4o-mini-transcribe` by default.
- The gateway returns plain text; the UI inserts it into the `Message` composer
  and does not auto-send.

This matches the current architecture: Codex App Server receives text and image
items, while speech recognition stays a gateway concern before the Codex turn is
created.

## Hard Prerequisite

iPhone LAN microphone capture requires a secure browser context. MDN documents
`getUserMedia()` as available only in secure contexts, and says insecure
contexts expose `navigator.mediaDevices` as `undefined`.

Current LAN usage such as:

```text
http://192.168.1.100:8787
```

is therefore not a reliable target for microphone input. Before exposing a mic
button, the gateway needs one of:

- local HTTPS support in `src/server.js` with configured cert/key;
- a trusted local reverse proxy such as Caddy or nginx;
- a native iOS wrapper later.

The UI should also feature-detect `navigator.mediaDevices?.getUserMedia`,
`window.MediaRecorder`, and supported audio MIME types. If HTTPS or recording is
unavailable, the mic button should show an actionable disabled state instead of
failing after tap.

## Browser Capture Layer

Use `getUserMedia({ audio: true })` to request the microphone and
`MediaRecorder` to produce a compressed audio blob.

Important browser facts:

- `getUserMedia` requires HTTPS, `file:///`, or `localhost`, plus user
  permission.
- `MediaRecorder` is broadly available, but MIME/container support varies.
- WebKit's MediaRecorder guidance says Safari supports MP4 with AAC audio, so
  iPhone should prefer `audio/mp4` or a compatible MP4/AAC output when available.
- Other browsers commonly support WebM/Opus. The client must select the first
  supported type with `MediaRecorder.isTypeSupported(...)`.

Candidate MIME preference:

```text
audio/mp4
audio/webm;codecs=opus
audio/webm
audio/mpeg
audio/wav
```

The OpenAI transcription endpoint supports `mp3`, `mp4`, `mpeg`, `mpga`, `m4a`,
`wav`, and `webm`, with file uploads limited to 25 MB.

## Recognition Options

### 1. OpenAI Audio Transcriptions

Best fit for MVP.

Primary source: OpenAI developer docs and OpenAPI spec.

Pros:

- Official API supports `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`,
  `whisper-1`, and diarization model variants.
- Good Russian and mixed Russian/English support.
- Supports prompts for `gpt-4o-transcribe` and `gpt-4o-mini-transcribe`, useful
  for project terms such as `BAZA`, `Codex`, `Zed`, `AGENTS.md`, and paths.
- Easy to keep `OPENAI_API_KEY` only on the gateway.
- No new frontend ML payloads or local model downloads.

Cons:

- Requires external API access from the laptop.
- Audio leaves the local machine for transcription.
- Needs server-side validation and request limits.

MVP server contract:

```http
POST /api/audio/transcribe
```

Request:

```json
{
  "audio": {
    "name": "voice.mp4",
    "type": "audio/mp4",
    "size": 123456,
    "dataUrl": "data:audio/mp4;base64,..."
  },
  "language": "ru"
}
```

Response:

```json
{
  "text": "..."
}
```

Implementation notes:

- Do not expose `OPENAI_API_KEY` to the browser.
- Cap clip size below OpenAI's 25 MB limit; for mobile UX start with a stricter
  local limit such as 8-15 MB or 60 seconds.
- Prefer in-memory upload to OpenAI. If temporary files are needed, store them
  under `.zed-mob/uploads/audio/` with `0600` permissions and delete them after
  transcription.
- Use a prompt that preserves code terms and punctuation.
- Insert transcript into the composer for user review, not auto-send.

### 2. OpenAI Transcriptions With `stream=true`

Useful later, not needed for first MVP.

The Audio Transcriptions endpoint can stream transcript events for a completed
audio recording. That helps show partial text while the server processes the
clip, but it still follows a push-to-talk "record then upload" UX.

Use this only after the non-streaming endpoint works.

### 3. OpenAI Realtime Transcription

Good future option for live dictation, not MVP.

Realtime transcription supports browser/mobile use through WebSocket or WebRTC
and transcription sessions with VAD, noise reduction, and incremental
transcript events.

Pros:

- Lower latency.
- Server VAD can segment speech.
- Ephemeral client secrets are designed for browser/mobile clients.

Cons:

- More moving parts than the current gateway needs.
- Requires raw audio streaming, session lifecycle, ordering by `item_id`, and
  reconnect behavior.
- Better for continuous dictation than a simple "record, insert text" button.

### 4. Web Speech API `SpeechRecognition`

Not recommended for this product as the primary path.

MDN marks `SpeechRecognition` as limited availability and notes that some
browsers use a server-based recognition engine, so audio may be sent to a vendor
service and may not work offline. Browser support and behavior are inconsistent
enough that this should only be an optional fallback after feature detection.

### 5. Native Apple Speech Framework

Good only if we later build a real iOS app or native wrapper.

Apple's Speech framework supports live or prerecorded audio, authorization, and
availability checks. `SFSpeechRecognizer` can use a locale and has
`supportsOnDeviceRecognition`, but some languages or devices may require
network access.

This is outside the current PWA/gateway scope.

### 6. Local Laptop ASR

Possible future privacy/offline provider.

Options:

- `whisper.cpp`: high-performance local Whisper inference; supports macOS,
  iOS, WebAssembly, and an HTTP server example. It can use Apple Silicon
  acceleration and quantized models.
- OpenAI Whisper Python package: canonical open-source model implementation,
  but heavier for this Node gateway and generally needs Python/PyTorch/FFmpeg.
- Vosk: offline toolkit with Node bindings, streaming API, small models, and
  Russian support.
- sherpa-onnx: local streaming/non-streaming ASR with JavaScript, Swift,
  WebAssembly, iOS, macOS, and many pretrained models, including Russian.
- WhisperKit / Argmax OSS Swift: strong Apple-native option and includes a
  local server that implements OpenAI-compatible audio transcription endpoints.

Pros:

- Can keep audio local.
- Can work without cloud API access.
- Useful if privacy or API cost becomes the main requirement.

Cons:

- Adds model downloads, CPU/GPU load, versioning, and ops complexity.
- More work to get robust Russian/mixed-code accuracy than OpenAI cloud STT.
- Browser/WASM variants are too heavy for an iPhone PWA MVP.

### 7. Browser WASM / WebGPU ASR

Technically possible, not recommended for MVP.

Transformers.js supports automatic speech recognition in the browser through
ONNX Runtime and can run on CPU/WASM or WebGPU. For an iPhone PWA this means
large model downloads, warm-up latency, memory pressure, and inconsistent WebGPU
availability. It is better suited for demos or a later offline mode, not the
first voice input feature.

### 8. Other Managed STT Providers

Alternatives if OpenAI transcription quality or latency is insufficient:

- Mistral Voxtral Mini Transcribe: batch transcription endpoint with
  `voxtral-mini-latest` / `voxtral-mini-2602`, language hints, timestamps,
  diarization, and `context_bias` for custom terms.
- Google Cloud Speech-to-Text: sync, async, and gRPC streaming recognition.
- Azure Speech-to-text: real-time and batch transcription.
- AWS Transcribe: batch and live streaming transcription with custom
  vocabulary, language ID, speaker handling, and redaction features.
- Deepgram: live streaming audio transcription over SDK/WebSocket.
- AssemblyAI: streaming STT WebSocket API and async transcript APIs.

These are not recommended for the first implementation because they add new
provider credentials and product surface while OpenAI is already part of this
project's agent stack.

### Provider Fit For This Project

Best default for the first implementation: OpenAI `gpt-4o-mini-transcribe`.

Reasons:

- The project already depends on OpenAI/Codex behavior, so the gateway can keep
  one primary API account and one main failure surface.
- OpenAI's transcription endpoint accepts the iPhone-friendly formats that the
  browser capture layer should emit, including `mp4`, `m4a`, `wav`, and `webm`.
- `gpt-4o-mini-transcribe` supports prompts, which is useful for mixed
  Russian/English dictation with terms like `BAZA`, `Codex`, `Zed`,
  `AGENTS.md`, route names, and file paths.
- The MVP needs a completed clip to text, not live captions. A simple
  non-streaming gateway call is therefore lower risk than realtime audio
  sessions.

Mistral is a good second provider, not a blocker for MVP. Its Voxtral Mini
Transcribe API is especially interesting because it has a simple
`/v1/audio/transcriptions` endpoint, long-audio support, timestamps,
diarization, and `context_bias`. The tradeoff is another credential, another
provider-specific error/rate-limit surface, and no local evidence yet that it is
more accurate for this project's actual Russian dictation plus code terms.

Recommended implementation shape:

- Build a provider adapter behind one local endpoint:
  `POST /api/audio/transcribe`.
- Default env:
  `ZED_MOB_STT_PROVIDER=openai`,
  `ZED_MOB_STT_MODEL=gpt-4o-mini-transcribe`.
- Optional Mistral env:
  `ZED_MOB_STT_PROVIDER=mistral`,
  `ZED_MOB_STT_MODEL=voxtral-mini-latest`,
  `MISTRAL_API_KEY=...`.
- Never call OpenAI or Mistral directly from the browser; API keys must stay on
  the local gateway.
- Add a small benchmark before changing the default provider: 20 short clips
  from the actual usage pattern, mostly Russian with project/code vocabulary,
  measured for transcription quality, latency, and error handling.

## Recommended MVP Plan

1. Add HTTPS LAN mode or document a supported local reverse proxy path.
2. Add server-side `POST /api/audio/transcribe` with a provider adapter.
3. Add client mic button state machine:
   `idle -> permission -> recording -> transcribing -> inserted/error`.
4. Select supported MIME type at runtime, preferring iPhone-compatible MP4/AAC.
5. Insert transcript into the `Message` composer without sending it.
6. Add visible errors for insecure origin, missing microphone permission,
   unsupported browser recording, oversized audio, and missing server API key.
7. Verify on laptop browser and iPhone browser.

## Source Index

OpenAI sources:

- https://developers.openai.com/api/docs/guides/speech-to-text
- https://developers.openai.com/api/docs/guides/realtime-transcription
- https://developers.openai.com/api/docs/api-reference/audio/createTranscription
- https://developers.openai.com/api/docs/models/gpt-4o-mini-transcribe
- https://github.com/openai/whisper

Browser and iOS sources:

- https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia
- https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder
- https://webkit.org/blog/11353/mediarecorder-api/
- https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API
- https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition
- https://developer.apple.com/documentation/speech/
- https://developer.apple.com/documentation/Speech/SFSpeechRecognizer
- https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio

Local/offline engine sources:

- https://github.com/ggml-org/whisper.cpp
- https://github.com/alphacep/vosk-api
- https://github.com/k2-fsa/sherpa-onnx
- https://github.com/argmaxinc/WhisperKit
- https://github.com/huggingface/transformers.js

Managed provider sources:

- https://docs.mistral.ai/studio-api/audio/speech_to_text
- https://docs.mistral.ai/studio-api/audio/speech_to_text/offline_transcription
- https://docs.mistral.ai/api/endpoint/audio/transcriptions
- https://docs.mistral.ai/models/model-cards/voxtral-mini-transcribe-26-02
- https://docs.mistral.ai/studio-api/audio/speech_to_text/realtime_transcription
- https://docs.cloud.google.com/speech-to-text/docs/speech-to-text-requests
- https://learn.microsoft.com/en-us/azure/ai-services/speech-service/index-speech-to-text
- https://aws.amazon.com/documentation-overview/transcribe/
- https://developers.deepgram.com/docs/live-streaming-audio
- https://www.assemblyai.com/docs/api-reference/streaming
