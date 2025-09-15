import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class ImageHelpers {
  static Widget buildImage(dynamic source,
      {double w = 44, double h = 44, BoxFit fit = BoxFit.cover}) {
    final String b64 = (source['fotoBase64'] ?? '') as String;
    final String path = (source['foto'] ?? '') as String;

    if (b64.isNotEmpty) {
      try {
        return Image.memory(base64Decode(b64), width: w, height: h, fit: fit);
      } catch (_) {}
    }
    if (path.startsWith('http')) {
      return Image.network(path,
          width: w, height: h, fit: fit,
          errorBuilder: (_, __, ___) => placeholder(w, h, broken: true));
    }
    if (path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), width: w, height: h, fit: fit);
    }
    return placeholder(w, h);
  }

  static Widget placeholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey[300],
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.6),
    );
  }
}
