import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/command_result.dart';
import '../models/intent.dart';
import 'app_resolver.dart';
import 'contacts_service.dart';
import 'phone_control_service.dart';
import 'user_preferences.dart';

class ActionExecutor {
  ActionExecutor(
    this._contactsService,
    this._appResolver, [
    PhoneControlService? phoneControlService,
  ]) : _phoneControlService = phoneControlService ?? PhoneControlService();

  final VoiceContactsService _contactsService;
  final AppResolver _appResolver;
  final PhoneControlService _phoneControlService;

  Future<CommandResult> execute(VoiceIntent intent) async {
    try {
      final target = intent.target?.trim();
      switch (intent.action) {
        case VoiceAction.abrirWhatsappContato:
          return _openWhatsapp(target);
        case VoiceAction.ligarPara:
          return _callContact(target);
        case VoiceAction.enviarMensagem:
          return _sendWhatsappMessage(
            target,
            intent.parameters['mensagem'] ?? intent.message,
          );
        case VoiceAction.abrirApp:
          return _openApp(target);
        case VoiceAction.tocarMusica:
          return _searchSpotifyOrYouTube(target);
        case VoiceAction.navegar:
          return _navigateTo(target);
        case VoiceAction.pesquisarGoogle:
          return _googleSearch(target);
        case VoiceAction.definirAlarme:
          return _openAlarmApp(intent.horario);
        case VoiceAction.voltar:
          return _goBack();
        case VoiceAction.fecharAplicativo:
          return _closeCurrentApp();
        case VoiceAction.fecharAppExterno:
          return _closeExternalApp(target);
        case VoiceAction.mapearCelular:
          return _mapPhoneApps();
        case VoiceAction.desconhecido:
          return CommandResult.fail('Não consegui entender o comando.');
      }
    } catch (e) {
      await HapticFeedback.heavyImpact();
      return CommandResult.fail(
        'Não foi possível executar o comando.',
        debugInfo: '$e',
      );
    }
  }

  Future<CommandResult> _openWhatsapp(String? name) async {
    final phone = await _resolvePhone(name);
    if (phone == null) {
      return CommandResult.fail('Não encontrei o contato para o WhatsApp.');
    }

    final uri = Uri.parse('https://wa.me/$phone');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return CommandResult.fail('Não consegui abrir o WhatsApp.');
    }
    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok('Abrindo WhatsApp.');
  }

  Future<CommandResult> _callContact(String? name) async {
    final phone = await _resolvePhone(name);
    if (phone == null) {
      return CommandResult.fail('Não encontrei número para ligação.');
    }

    final uri = Uri.parse('tel:$phone');
    if (!await launchUrl(uri)) {
      return CommandResult.fail('Não consegui iniciar a ligação.');
    }
    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok('Iniciando ligação.');
  }

  Future<CommandResult> _sendWhatsappMessage(
    String? name,
    String? message,
  ) async {
    final phone = await _resolvePhone(name);
    if (phone == null) {
      return CommandResult.fail(
        'Não encontrei contato para enviar a mensagem.',
      );
    }

    final body = message ?? '';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(body)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return CommandResult.fail('Não consegui abrir o WhatsApp para envio.');
    }
    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok('Abrindo WhatsApp para enviar mensagem.');
  }

  Future<CommandResult> _openApp(String? appName) async {
    if (appName == null || appName.isEmpty) {
      return CommandResult.fail('Informe o app para abrir.');
    }

    if (!Platform.isAndroid) {
      return CommandResult.fail(
        'Abertura direta de apps é limitada fora do Android.',
      );
    }

    final package = await _appResolver.resolvePackage(appName);
    if (package == null) {
      return CommandResult.fail('App "$appName" não mapeado.');
    }

    // Registra abertura para mapeamento automático (só nos primeiros 15 dias)
    await UserPreferences.registerAppOpen(appName, package);

    if (await _phoneControlService.openApp(package)) {
      await SystemSound.play(SystemSoundType.click);
      return CommandResult.ok('Abrindo $appName.');
    }

    final intent = AndroidIntent(
      action: 'action_main',
      package: package,
      category: 'android.intent.category.LAUNCHER',
    );
    try {
      await intent.launch();
    } catch (_) {
      return CommandResult.fail('Não encontrei o $appName instalado.');
    }
    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok('Abrindo $appName.');
  }

  Future<CommandResult> _mapPhoneApps() async {
    if (!Platform.isAndroid) {
      return CommandResult.fail(
        'Mapeamento de aplicativos está disponível apenas no Android.',
      );
    }

    final count = await _appResolver.mapInstalledApps();
    if (count == 0) {
      return CommandResult.fail(
        'Não encontrei aplicativos instalados para mapear.',
      );
    }

    return CommandResult.ok('Celular mapeado. Encontrei $count aplicativos.');
  }

  Future<CommandResult> _searchSpotifyOrYouTube(String? query) async {
    if (query == null || query.isEmpty) {
      return CommandResult.fail('Informe o nome da música.');
    }
    final uri = Uri.parse(
      'https://open.spotify.com/search/${Uri.encodeComponent(query)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return CommandResult.fail('Não consegui abrir o app de música.');
    }
    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok('Abrindo música: $query');
  }

  Future<CommandResult> _googleSearch(String? query) async {
    if (query == null || query.isEmpty) {
      return CommandResult.fail('Informe o que pesquisar.');
    }
    final uri = Uri.parse(
      'https://google.com/search?q=${Uri.encodeComponent(query)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return CommandResult.fail('Não consegui abrir a pesquisa.');
    }
    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok('Pesquisando por $query');
  }

  Future<CommandResult> _navigateTo(String? location) async {
    if (location == null || location.isEmpty) {
      return CommandResult.fail('Informe para onde navegar.');
    }
    final uri = Uri.parse(
      'https://maps.google.com/?q=${Uri.encodeComponent(location)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return CommandResult.fail('Não consegui abrir o mapa.');
    }
    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok('Navegando para $location');
  }

  Future<CommandResult> _openAlarmApp(String? time) async {
    if (!Platform.isAndroid) {
      return CommandResult.ok(
        'Abra o app relógio para configurar o alarme${time != null ? ' às $time' : ''}.',
      );
    }

    const intent = AndroidIntent(action: 'android.intent.action.SHOW_ALARMS');
    try {
      await intent.launch();
      return CommandResult.ok(
        'Abrindo relógio para configurar o alarme${time != null ? ' às $time' : ''}.',
      );
    } catch (_) {
      return CommandResult.fail('Não consegui abrir o app de relógio.');
    }
  }

  Future<CommandResult> _closeCurrentApp() async {
    return _pressBack(times: 3, successMessage: 'Fechando aplicativo.');
  }

  Future<CommandResult> _closeExternalApp(String? appName) async {
    if (Platform.isIOS) {
      return CommandResult.fail(
        'No iOS, use os gestos do sistema para fechar apps.',
      );
    }
    if (!Platform.isAndroid) {
      return CommandResult.fail('Comando disponível apenas no Android.');
    }
    final isEnabled = await _phoneControlService.isAccessibilityEnabled();
    if (!isEnabled) {
      await _phoneControlService.openAccessibilitySettings();
      return CommandResult.fail(
        'Ative o serviço VozComando em Acessibilidade para usar esse comando.',
      );
    }
    final success = await _phoneControlService.pressHome(times: 2);
    if (!success) return CommandResult.fail('Não consegui ir para a tela inicial.');
    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok(
      appName != null ? 'Indo para a tela inicial.' : 'Tela inicial.',
    );
  }

  Future<CommandResult> _goBack() async {
    return _pressBack(times: 1, successMessage: 'Voltando.');
  }

  Future<CommandResult> _pressBack({
    required int times,
    required String successMessage,
  }) async {
    if (Platform.isIOS) {
      return CommandResult.fail(
        'No iOS, aplicativos não podem executar voltar ou controlar outros apps. Use os gestos do sistema ou Atalhos da Siri para ações permitidas.',
      );
    }

    if (!Platform.isAndroid) {
      return CommandResult.fail(
        'Esse comando está disponível apenas no Android.',
      );
    }

    final isEnabled = await _phoneControlService.isAccessibilityEnabled();
    if (!isEnabled) {
      await _phoneControlService.openAccessibilitySettings();
      return CommandResult.fail(
        'Ative o serviço VozComando em Acessibilidade para usar comandos de navegação.',
      );
    }

    final success = await _phoneControlService.pressBack(times: times);
    if (!success) {
      return CommandResult.fail('Não consegui executar voltar.');
    }

    await SystemSound.play(SystemSoundType.click);
    return CommandResult.ok(successMessage);
  }

  Future<String?> _resolvePhone(String? query) async {
    if (query == null || query.isEmpty) return null;
    final matches = await _contactsService.searchByName(query);
    if (matches.isEmpty) return null;
    return matches.first.phone?.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<List<ContactMatch>> findContacts(String query) {
    return _contactsService.searchByName(query);
  }
}
