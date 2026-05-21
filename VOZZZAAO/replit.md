# VozComando

A voice-command assistant app targeting Android, built with Flutter (Dart) and a companion Node.js/Express API.

## Architecture

- **Flutter app** (`lib/`, `android/`): Mobile app that listens for voice commands in Portuguese (pt-BR), parses intents locally via regex, and executes phone actions (WhatsApp, calls, alarms, Google search, etc.).
- **Intent API** (`src/`): Node.js/Express server (TypeScript) that exposes a `/api/intent` endpoint for structured intent parsing. This is what runs in the Replit preview.

## Running the project

The Express API server runs on port 5000 via `npm run dev` (uses `tsx watch` for hot-reload).

### API Endpoint

**POST /api/intent**

```json
{
  "texto": "abrir whatsapp conversa com João",
  "contexto": { "ultimaAcao": "...", "ultimoAlvo": "..." }
}
```

Returns a structured intent object with `acao`, `alvo`, `parametros`, `confianca`, `ambiguo`, and `perguntaConfirmacao`.

## User preferences

- Language: Portuguese (pt-BR) is the target language for voice commands.
