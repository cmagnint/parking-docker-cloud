import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:parking/utils/globals.dart';

class TextToBitmapService {
  static const int paperWidthPx = 384; // 58mm papel térmico

  // Convertir texto a comandos raster con mejor control
  static List<int> textToRasterCommands(
    String text, {
    int fontSize = 14, // Más pequeño por defecto
    bool bold = false,
    TextAlign align = TextAlign.left,
  }) {
    try {
      final textLines = text.split('\n');
      final lineHeight = fontSize + 4; // Menos espacio entre líneas
      final imageHeight = textLines.length * lineHeight + 20; // Menos margen

      // Crear imagen blanca
      final image = img.Image(width: paperWidthPx, height: imageHeight);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));

      // Dibujar cada línea
      int yOffset = 10; // Margen superior reducido
      for (String line in textLines) {
        if (line.trim().isEmpty) {
          yOffset += lineHeight ~/ 2;
          continue;
        }

        int xOffset = _calculateXOffset(line, fontSize, align);
        _drawText(image, line, xOffset, yOffset, fontSize, bold);
        yOffset += lineHeight;
      }

      // Convertir a bitmap monocromático
      final bitmapData = _convertToMonochromeBitmap(image);

      // Generar comandos raster
      return _generateRasterCommands(bitmapData, paperWidthPx, imageHeight);
    } catch (e) {
      loggerGlobal.e('Error al convertir texto a bitmap: $e');
      return [];
    }
  }

  static int _calculateXOffset(String text, int fontSize, TextAlign align) {
    final charWidth = fontSize ~/ 2;
    final textWidth = text.length * charWidth;

    switch (align) {
      case TextAlign.center:
        // En lugar de centrar perfectamente, mover un poco a la izquierda
        return ((paperWidthPx - textWidth) ~/ 2) -
            30; // 30 píxeles a la izquierda
      case TextAlign.right:
        return paperWidthPx - textWidth - 10;
      default:
        return 20; // Margen izquierdo
    }
  }

  static void _drawText(
      img.Image image, String text, int x, int y, int size, bool bold) {
    // Usar fuente más pequeña
    final font = size <= 14 ? img.arial14 : img.arial24;

    img.drawString(
      image,
      text,
      font: font,
      x: x,
      y: y,
      color: img.ColorRgb8(0, 0, 0),
    );

    if (bold) {
      img.drawString(
        image,
        text,
        font: font,
        x: x + 1,
        y: y,
        color: img.ColorRgb8(0, 0, 0),
      );
    }
  }

  static Uint8List _convertToMonochromeBitmap(img.Image image) {
    final width = image.width;
    final height = image.height;
    final bytesPerLine = (width + 7) ~/ 8;

    final bitmap = Uint8List(bytesPerLine * height);
    int byteIndex = 0;

    for (int y = 0; y < height; y++) {
      int bitIndex = 0;
      int currentByte = 0;

      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);

        if (luminance < 128) {
          currentByte |= (1 << (7 - bitIndex));
        }

        bitIndex++;
        if (bitIndex == 8) {
          bitmap[byteIndex++] = currentByte;
          currentByte = 0;
          bitIndex = 0;
        }
      }

      if (bitIndex > 0) {
        bitmap[byteIndex++] = currentByte;
      }
    }

    return bitmap;
  }

  static List<int> _generateRasterCommands(
      Uint8List bitmapData, int width, int height) {
    List<int> commands = [];

    // Comando raster: GS v 0
    commands.addAll([0x1D, 0x76, 0x30, 0x00]);

    // Ancho en bytes (little endian)
    int widthBytes = (width + 7) ~/ 8;
    commands.add(widthBytes & 0xFF);
    commands.add((widthBytes >> 8) & 0xFF);

    // Alto en píxeles (little endian)
    commands.add(height & 0xFF);
    commands.add((height >> 8) & 0xFF);

    // Datos del bitmap
    commands.addAll(bitmapData);

    return commands;
  }
}

enum TextAlign {
  left,
  center,
  right,
}
