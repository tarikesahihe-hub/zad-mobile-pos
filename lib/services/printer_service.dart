import 'dart:io';
import 'dart:typed_data';
import '../models/sale.dart';

/// ═══════════════════════════════════════════════════════════════
/// Printer Service - Network ESC/POS thermal printer support
/// ═══════════════════════════════════════════════════════════════

class PrinterService {
  Socket? _socket;

  Future<bool> connect(String ip, {int port = 9100}) async {
    try {
      _socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      return true;
    } catch (_) {
      _socket = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _socket?.flush();
      await _socket?.close();
    } catch (_) {
      // ignore
    } finally {
      _socket = null;
    }
  }

  Future<void> printSaleReceipt(Sale sale) async {
    final socket = _socket;
    if (socket == null) {
      throw Exception('الطابعة غير متصلة');
    }
    socket.add(_buildReceipt(sale));
    await socket.flush();
  }

  Uint8List _buildReceipt(Sale sale) {
    final bytes = BytesBuilder();

    bytes.add(_textCenter('*** ZAD POS ***'));
    bytes.add(_line());

    bytes.add(_text('فاتورة: ${sale.invoiceNumber}'));
    bytes.add(_text('التاريخ: ${sale.date}'));

    bytes.add(_line());

    for (final item in sale.items) {
      bytes.add(
        _text(
          '${item.productName} x${item.quantity}  ${item.total.toStringAsFixed(2)}',
        ),
      );
    }

    bytes.add(_line());

    if (sale.discount > 0) {
      bytes.add(_text('الخصم: ${sale.discount.toStringAsFixed(2)} د.ج'));
    }
    if (sale.tax > 0) {
      bytes.add(_text('الضريبة: ${sale.tax.toStringAsFixed(2)} د.ج'));
    }

    bytes.add(
      _textBold(
        'الإجمالي: ${sale.total.toStringAsFixed(2)} د.ج',
      ),
    );

    bytes.add(_line());

    bytes.add(_textCenter('شكراً لزيارتكم'));
    bytes.add(_feed(4));
    bytes.add(_cut());

    return bytes.toBytes();
  }

  Uint8List _text(String text) {
    return Uint8List.fromList(
      [...text.codeUnits, 0x0A],
    );
  }

  Uint8List _textBold(String text) {
    return Uint8List.fromList([
      0x1B,
      0x45,
      0x01,
      ...text.codeUnits,
      0x0A,
      0x1B,
      0x45,
      0x00,
    ]);
  }

  Uint8List _textCenter(String text) {
    return Uint8List.fromList([
      0x1B,
      0x61,
      0x01,
      ...text.codeUnits,
      0x0A,
      0x1B,
      0x61,
      0x00,
    ]);
  }

  Uint8List _line() {
    return _text(
      '--------------------------------',
    );
  }

  Uint8List _feed(int lines) {
    return Uint8List.fromList(
      List.generate(lines, (_) => 0x0A),
    );
  }

  Uint8List _cut() {
    return Uint8List.fromList([
      0x1D,
      0x56,
      0x00,
    ]);
  }
}
