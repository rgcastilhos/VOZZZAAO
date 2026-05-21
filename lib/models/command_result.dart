class CommandResult {
  const CommandResult({
    required this.success,
    required this.message,
    this.debugInfo,
    this.requiresConfirmation = false,
    this.options,
  });

  final bool success;
  final String message;
  final String? debugInfo;
  final bool requiresConfirmation;
  final List<String>? options;

  bool get sucesso => success;
  String get mensagem => message;
  bool get precisaConfirmacao => requiresConfirmation;
  List<String>? get opcoes => options;

  factory CommandResult.ok(String message) {
    return CommandResult(success: true, message: message);
  }

  factory CommandResult.fail(
    String message, {
    String? debugInfo,
    bool requiresConfirmation = false,
    List<String>? options,
  }) {
    return CommandResult(
      success: false,
      message: message,
      debugInfo: debugInfo,
      requiresConfirmation: requiresConfirmation,
      options: options,
    );
  }
}
