import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../draw/board.dart';
import '../theme.dart';

/// Shares a drawing as a PNG (Telegram / WhatsApp / save) with the game's name on it.
Future<void> shareDrawing(BuildContext context, BoardModel board, {String? word}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final png = await boardToPng(board, caption: word);
    if (png == null) return;
    await SharePlus.instance.share(ShareParams(
      text: word == null ? 'نقاشی من تو «نقاشی بکش» 🎨' : 'این «$word» بود! 🎨 نقاشی بکش',
      files: [XFile.fromData(Uint8List.fromList(png), mimeType: 'image/png', name: 'naqashi.png')],
    ));
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text('اشتراک‌گذاری روی این گوشی کار نکرد'), backgroundColor: C.anar));
  }
}

/// Shares a room invite as text.
Future<void> shareInvite(String code) async {
  try {
    await SharePlus.instance.share(ShareParams(
      text: 'بیا «نقاشی بکش» بازی کنیم! 🎨\nکد اتاق: $code\nتو بازی بزن «با کد وارد شو» و کد رو بنویس.',
    ));
  } catch (_) {}
}
