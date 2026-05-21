import 'dart:developer' as developer;

import '../models/intent.dart';

class IntentParser {
  IntentParser();

  Future<VoiceIntent> parse(String text) async {
    developer.log('VOZ BRUTA DO STT: "$text"');

    final raw = text.trim().toLowerCase();
    final normalized = _removeAccents(raw);

    developer.log('NORMALIZADA: "$normalized"');

    final clean = normalized
        .replaceAll(RegExp(r'[.,!?;:]+\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    developer.log('LIMPA: "$clean"');

    if (clean.isEmpty) {
      developer.log('MATCH: NENHUM');
      return const VoiceIntent(action: VoiceAction.desconhecido);
    }

    final mapear = RegExp(
      r'^(?:mapear|sincronizar|linkar)\s+(?:celular|telefone|apps?|aplicativos?)$',
    ).firstMatch(clean);
    if (mapear != null) {
      developer.log('MATCH: MAPEAR_CELULAR');
      return const VoiceIntent(
        action: VoiceAction.mapearCelular,
        confidence: 0.96,
      );
    }

    final whatsapp =
        RegExp(
          r'abrir\s+whatsapp\s+(?:conversa\s+)?(?:com\s+)?(.+)',
        ).firstMatch(clean) ??
        RegExp(r'whatsapp\s+(?:com\s+)?(.+)').firstMatch(clean) ??
        RegExp(r'falar\s+(?:com\s+|no\s+whatsapp\s+)?(.+)').firstMatch(clean);
    if (whatsapp != null) {
      developer.log('MATCH: ABRIR_WHATSAPP');
      return VoiceIntent(
        action: VoiceAction.abrirWhatsappContato,
        target: whatsapp.group(1)?.trim(),
        confidence: 0.95,
      );
    }

    final ligar = RegExp(
      r'(?:ligar|telefonar|chamar)\s+(?:para\s+|pro\s+|pra\s+)?(.+)',
    ).firstMatch(clean);
    if (ligar != null) {
      developer.log('MATCH: LIGAR');
      return VoiceIntent(
        action: VoiceAction.ligarPara,
        target: ligar.group(1)?.trim(),
        requiresConfirmation: true,
        confidence: 0.9,
        confirmationQuestion:
            'Vou ligar para ${ligar.group(1)?.trim()}, confirma?',
      );
    }

    final mensagem = RegExp(
      r'mandar\s+(?:mensagem\s+|msg\s+)?(?:para\s+|pro\s+|pra\s+)?(.+?)\s+(?:dizendo\s+|que\s+|falando\s+)(.+)',
    ).firstMatch(clean);
    if (mensagem != null) {
      developer.log('MATCH: ENVIAR_MSG');
      final alvo = mensagem.group(1)?.trim();
      final texto = mensagem.group(2)?.trim();
      return VoiceIntent(
        action: VoiceAction.enviarMensagem,
        target: alvo,
        message: texto,
        parameters: <String, String?>{'mensagem': texto},
        requiresConfirmation: true,
        confidence: 0.93,
        confirmationQuestion: 'Vou enviar mensagem para $alvo, confirma?',
      );
    }

    final app = RegExp(r'^abrir\s+(.+)$').firstMatch(clean);
    if (app != null) {
      developer.log('MATCH: ABRIR_APP');
      return VoiceIntent(
        action: VoiceAction.abrirApp,
        target: app.group(1)?.trim(),
        confidence: 0.82,
      );
    }

    final musica = RegExp(
      r'^(?:tocar|ouvir|play)\s+(?:musica\s+)?(.+)$',
    ).firstMatch(clean);
    if (musica != null) {
      developer.log('MATCH: TOCAR_MUSICA');
      return VoiceIntent(
        action: VoiceAction.tocarMusica,
        target: musica.group(1)?.trim(),
        confidence: 0.88,
      );
    }

    final pesquisa = RegExp(
      r'^(?:pesquisar|procurar|buscar)\s+(.+)$',
    ).firstMatch(clean);
    if (pesquisa != null) {
      developer.log('MATCH: PESQUISAR');
      return VoiceIntent(
        action: VoiceAction.pesquisarGoogle,
        target: pesquisa.group(1)?.trim(),
        confidence: 0.88,
      );
    }

    if (RegExp(
      r'^(?:fechar|feche|encerrar|sair|quit|sair do app|fechar app|fechar aplicativo|feche o aplicativo|feche aplicativo)$',
    ).hasMatch(clean)) {
      developer.log('MATCH: FECHAR_APP');
      return const VoiceIntent(
        action: VoiceAction.fecharAplicativo,
        confidence: 0.96,
      );
    }

    if (RegExp(r'^(?:voltar|retornar|back|voltar atras)$').hasMatch(clean)) {
      developer.log('MATCH: VOLTAR');
      return const VoiceIntent(action: VoiceAction.voltar, confidence: 0.95);
    }

    developer.log('MATCH: NENHUM');
    return const VoiceIntent(action: VoiceAction.desconhecido);
  }

  String _removeAccents(String s) {
    return s
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }
}
