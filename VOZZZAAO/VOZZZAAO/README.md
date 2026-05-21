# VozComando

Aplicativo Flutter para executar ações do celular por comandos de voz em português (`pt-BR`).

## Fluxo

`voz -> texto (STT) -> intenção -> resolução -> execução -> feedback`

## Funcionalidades atuais

- Tela única com botão de microfone grande no centro e estados (`aguardando`, `ouvindo`, `processando`, `executando`, `erro`).
- Reconhecimento com `speech_to_text` e transcrição parcial em tempo real.
- Feedback por voz com `flutter_tts`.
- Parser 100% local por regex (sem servidor e sem IA).
- Resolução de contatos local com `flutter_contacts` + fuzzy matching (limiar de 60%).
- Execução de ações: abrir WhatsApp com contato, enviar mensagem no WhatsApp, ligar, abrir app (Android), tocar música, pesquisar no Google, navegar no Maps e abrir app de relógio para alarme.

## Estrutura principal

```text
lib/
├── main.dart
├── screens/
│   └── voice_command_screen.dart
├── services/
│   ├── speech_service.dart
│   ├── tts_service.dart
│   ├── intent_parser.dart
│   ├── contacts_service.dart
│   ├── action_executor.dart
│   └── app_resolver.dart
└── models/
    ├── intent.dart
    └── command_result.dart

```

## Dependências Flutter

- `speech_to_text`
- `flutter_tts`
- `flutter_contacts`
- `url_launcher`
- `android_intent_plus`
- `permission_handler`

## Permissões Android

- `INTERNET`
- `RECORD_AUDIO`
- `READ_CONTACTS`
- `CALL_PHONE`

Também foram adicionadas `queries` para alguns pacotes externos (WhatsApp, Instagram, Spotify e YouTube Music).

## Limitações por plataforma

- **Android**: melhor suporte para abrir apps específicos por `intent`.
- **iOS**: abertura de apps externos e automações profundas são mais limitadas.
- Envio automático de mensagens em apps de terceiros não é permitido por segurança; o app abre o destino para o usuário concluir.

## Regras e limitações

- Funciona offline para interpretação de comando (regex local), mas o `speech_to_text` pode depender de internet em muitos aparelhos.
- O app confirma antes de ligar ou enviar mensagem.
- Não envia mensagens automaticamente sem ação do usuário; abre o destino para confirmação final.
- Não cria alarme automaticamente; abre o app de relógio.
- iOS possui mais restrições para abertura de apps externos.

## Como executar o app Flutter

```bash
flutter pub get
flutter run
```
