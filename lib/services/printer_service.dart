import 'dart:io';
import 'dart:typed_data';
import '../models/sale.dart';

/// ═══════════════════════════════════════════════════════════════
/// Printer Service
/// يدعم:
/// - USB
/// - Network
/// - Bluetooth (مستقبلاً)
/// - حفظ PDF (مستقبلاً)
/// ═══════════════════════════════════════════════════════════════

enum PrinterType {
  usb,
  network,
  bluetooth,
}

class PrinterConfig {
  final PrinterType type;
  final String address;
  final int port;

  const PrinterConfig({
    required this.type,
    required this.address,
    this.port = 9100,
  });
}

class PrinterService {
  static final PrinterService instance = PrinterService._();

  PrinterService._();

  PrinterConfig? _config;

  void configure(PrinterConfig config) {
    _config = config;
  }

  Future<bool> printSale(Sale sale) async {
    if (_config == null) {
      throw Exception('Printer not configured');
    }

    switch (_config!.type) {
      case PrinterType.network:
        return await _printNetwork(sale);

      case PrinterType.usb:
        return await _printUsb(sale);

      case PrinterType.bluetooth:
        return await _printBluetooth(sale);
    }
  }

  Future<bool> _printNetwork(Sale sale) async {
    try {
      final socket = await Socket.connect(
        _config!.address,
        _config!.port,
        timeout: const Duration(seconds: 5),
      );

      socket.add(_buildReceipt(sale));
      await socket.flush();
      await socket.close();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _printUsb(Sale sale) async {
    // TODO:
    // تنفيذ USB باستخدام esc_pos_usb أو أي مكتبة مناسبة
    return false;
  }

  Future<bool> _printBluetooth(Sale sale) async {
    // TODO:
    // تنفيذ Bluetooth
    return false;
  }

  Uint8List _buildReceipt(Sale sale) {
    final bytes = BytesBuilder();

    bytes.add(_textCenter('*** ZAD POS ***'));
    bytes.add(_line());

    bytes.add(_text('Invoice: ${sale.id}'));
    bytes.add(_text('Date: ${sale.date}'));

    bytes.add(_line());

    for (final item in sale.items) {
      bytes.add(
        _text(
          '${item.productName} x${item.quantity}  ${item.total}',
        ),
      );
    }    bytes.add(_line());

    bytes.add(
      _textBold(
        'TOTAL: ${sale.total.toStringAsFixed(2)}',
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
