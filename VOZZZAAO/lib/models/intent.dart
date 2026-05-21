enum VoiceAction {
  abrirWhatsappContato,
  ligarPara,
  enviarMensagem,
  abrirApp,
  tocarMusica,
  navegar,
  definirAlarme,
  pesquisarGoogle,
  voltar,
  fecharAplicativo,
  fecharAppExterno,
  mapearCelular,
  desconhecido,
}

class VoiceIntent {
  const VoiceIntent({
    required this.action,
    this.target,
    this.parameters = const <String, String?>{},
    this.confidence = 0.8,
    this.message,
    this.time,
    this.requiresConfirmation = false,
    this.ambiguous = false,
    this.confirmationQuestion,
  });

  final VoiceAction action;
  final String? target;
  final Map<String, String?> parameters;
  final double confidence;
  final String? message;
  final String? time;
  final bool requiresConfirmation;
  final bool ambiguous;
  final String? confirmationQuestion;

  bool get isKnown => action != VoiceAction.desconhecido;

  String get acao => action.name;
  String? get alvo => target;
  String? get mensagem => message ?? parameters['mensagem'];
  String? get horario => time ?? parameters['horario'];
  double get confianca => confidence;
  bool get ambiguo => ambiguous;
  String? get perguntaConfirmacao => confirmationQuestion;

  static VoiceAction actionFromApi(String value) {
    switch (value) {
      case 'ABRIR_WHATSAPP_CONTATO':
        return VoiceAction.abrirWhatsappContato;
      case 'LIGAR_PARA':
        return VoiceAction.ligarPara;
      case 'ENVIAR_SMS':
      case 'ENVIAR_WHATSAPP':
      case 'ENVIAR_MENSAGEM':
        return VoiceAction.enviarMensagem;
      case 'ABRIR_APP':
        return VoiceAction.abrirApp;
      case 'TOCAR_MUSICA':
        return VoiceAction.tocarMusica;
      case 'NAVEGAR_ATE':
      case 'NAVEGAR':
        return VoiceAction.navegar;
      case 'DEFINIR_ALARME':
        return VoiceAction.definirAlarme;
      case 'PESQUISAR_GOOGLE':
        return VoiceAction.pesquisarGoogle;
      case 'VOLTAR':
        return VoiceAction.voltar;
      case 'FECHAR':
      case 'FECHAR_APP':
      case 'FECHAR_APLICATIVO':
        return VoiceAction.fecharAplicativo;
      case 'FECHAR_APP_EXTERNO':
        return VoiceAction.fecharAppExterno;
      case 'MAPEAR_CELULAR':
      case 'MAPEAR_APPS':
      case 'SINCRONIZAR_APPS':
        return VoiceAction.mapearCelular;
      default:
        return VoiceAction.desconhecido;
    }
  }
}
