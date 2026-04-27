import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'pari_prompt.dart';

class PariBrain {
  static final String _apiKey = Platform.environment['GOOGLE_API_KEY'] ?? '';

  late GenerativeModel _model;
  late ChatSession _chat;

  // Singleton
  static final PariBrain _instance = PariBrain._internal();
  factory PariBrain() => _instance;

  PariBrain._internal() {
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _apiKey,
      systemInstruction: Content.system(PariPrompt.systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.9,      // More creative = more human-like
        maxOutputTokens: 300,  // Keep replies short like real GF
        topP: 0.95,
      ),
    );
    _chat = _model.startChat();
  }

  // ── Main Chat ──────────────────────────────────
  Future<String> chat(String message, {String userName = 'Jaan'}) async {
    final timeLabel = _getTimeLabel();
    final prompt = '[$timeLabel] $userName: $message';

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _chat.sendMessage(Content.text(prompt));
        final text = response.text;
        if (text != null && text.isNotEmpty) return text;
      } catch (e) {
        // Reset chat session on error
        _chat = _model.startChat();
        await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }
    return 'Ek sec jaan, soch rahi hoon 🤔';
  }

  // ── Notification React ─────────────────────────
  Future<Map<String, String?>> reactToNotification({
    required String app,
    required String sender,
    required String message,
  }) async {
    try {
      final prompt = PariPrompt.notificationPrompt(app, sender, message);
      final res = await _model.generateContent([Content.text(prompt)]);
      final text = res.text ?? '';
      return {
        'reaction': _extract(text, 'REACTION'),
        'reply':    _extract(text, 'REPLY')?.let<String?>((r) => r == 'NONE' ? null : r),
        'priority': _extract(text, 'PRIORITY'),
      };
    } catch (_) {
      return {'reaction': 'Notification aayi hai 👀', 'reply': null, 'priority': 'NORMAL'};
    }
  }

  // ── WhatsApp Replies ───────────────────────────
  Future<Map<String, String>> whatsAppReplies(String sender, String msg) async {
    try {
      final prompt = PariPrompt.whatsAppPrompt(sender, msg);
      final res = await _model.generateContent([Content.text(prompt)]);
      final text = res.text ?? '';
      return {
        'friendly': _extract(text, 'FRIENDLY') ?? 'Haan 😊',
        'funny':    _extract(text, 'FUNNY')    ?? '😂',
        'short':    _extract(text, 'SHORT')    ?? 'Ok 👍',
      };
    } catch (_) {
      return {'friendly': 'Haan 😊', 'funny': '😂 ok bhai', 'short': 'Ok 👍'};
    }
  }

  // ── Email Reply ────────────────────────────────
  Future<Map<String, String>> emailReply(String subject, String from, String body) async {
    try {
      final prompt = PariPrompt.emailPrompt(subject, from, body);
      final res = await _model.generateContent([Content.text(prompt)]);
      final text = res.text ?? '';
      return {
        'pariReaction': _extract(text, 'PARI_REACTION') ?? 'Email aayi hai 📧',
        'subject':      _extract(text, 'SUBJECT')       ?? 'Re: $subject',
        'body':         text.contains('BODY:') ? text.split('BODY:').last.trim() : text,
      };
    } catch (_) {
      return {'pariReaction': 'Email 📧', 'subject': 'Re: $subject', 'body': ''};
    }
  }

  // ── Call Announce ──────────────────────────────
  Future<String> announceCall(String caller, {String gender = 'unknown', String relation = 'unknown'}) async {
    try {
      final prompt = PariPrompt.callPrompt(caller, gender, relation);
      final res = await _model.generateContent([Content.text(prompt)]);
      return res.text ?? '$caller ka call hai 📞';
    } catch (_) {
      return '$caller ka call aa raha hai 📞';
    }
  }

  // ── Shopping React ─────────────────────────────
  Future<String> shoppingReaction(String item, String price) async {
    try {
      final prompt = PariPrompt.shoppingPrompt(item, price);
      final res = await _model.generateContent([Content.text(prompt)]);
      return res.text ?? 'Itna expensive?! Mujhe bhi dilao 💅';
    } catch (_) {
      return 'Kya dekh raha hai? Mujhe bhi dikhao 👀';
    }
  }

  // ── Parse Phone Actions ────────────────────────
  List<Map<String, String>> parseActions(String text) {
    final regex = RegExp(r'\[([A-Z_]+):?([^\]]*)?]');
    return regex.allMatches(text).map((m) {
      return {'type': m.group(1) ?? '', 'param': m.group(2) ?? ''};
    }).toList();
  }

  // ── Helpers ────────────────────────────────────
  String _getTimeLabel() {
    final h = DateTime.now().hour;
    if (h >= 6  && h < 12) return 'Morning';
    if (h >= 12 && h < 17) return 'Afternoon';
    if (h >= 17 && h < 21) return 'Evening';
    if (h >= 21 && h < 24) return 'Night';
    return 'Late Night';
  }

  String? _extract(String text, String key) {
    try {
      return text.split('$key:').elementAt(1).split('\n').first.trim();
    } catch (_) {
      return null;
    }
  }
}

extension NullableExt<T> on T? {
  R? let<R>(R Function(T) block) => this == null ? null : block(this as T);
}
