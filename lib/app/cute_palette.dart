import 'package:flutter/material.dart';

abstract final class CuteColors {
  static const cream = Color(0xFFFFF7EF);
  static const surface = Color(0xFFFFFDFA);
  static const card = Color(0xFFFFFFFF);
  static const peachSurface = Color(0xFFFFF2E4);
  static const peachInput = Color(0xFFFFF3E8);

  static const text = Color(0xFF5A4A3F);
  static const textDark = Color(0xFF3A4A3F);
  static const textSoft = Color(0xFF6A594C);
  static const textMuted = Color(0xFFA8917F);
  static const textSubtle = Color(0xFFB6A395);
  static const textFaint = Color(0xFFBBA894);
  static const textDisabled = Color(0xFFCBB6A3);
  static const propeller = Color(0xFF8A7766);

  static const borderWarm = Color(0xFFF1E7DA);
  static const borderSoft = Color(0xFFEADFD2);
  static const borderFrame = Color(0xFFF4E7D8);
  static const borderLogo = Color(0xFFECE2D4);
  static const borderList = Color(0xFFF7EFE5);
  static const shadowWarm = Color(0xFFF4ECE1);
  static const shadowPeachSoft = Color(0xFFF0DDCA);
  static const gridWarm = Color(0xFFF0E4D4);

  static const matcha = Color(0xFF3F7D5C);
  static const matchaLight = Color(0xFF8AD6A3);
  static const matchaSoft = Color(0xFFB8E6C4);
  static const matchaEnd = Color(0xFF5CC78F);
  static const matchaShadow = Color(0xFF4FB87F);
  static const matchaMascotShadow = Color(0xFF6CC488);
  static const up = Color(0xFF2E9E6B);
  static const upTextAlt = Color(0xFF3F9E6B);
  static const upBackground = Color(0xFFEAFAF0);
  static const upBorder = Color(0xFFC4EBD1);
  static const upRing = Color(0xFF9BDCB3);
  static const upLineShadow = Color(0xFFB9E7CD);
  static const upNode = Color(0xFF7CCFA0);
  static const upNodeStrong = Color(0xFF4BBD84);
  static const blobMatcha = Color(0xFFE2F5E6);

  static const down = Color(0xFFE0604A);
  static const downLight = Color(0xFFFF9D86);
  static const downBackground = Color(0xFFFDEEEB);
  static const downShadow = Color(0xFFCF5440);
  static const downLineShadow = Color(0xFFF6C4B8);
  static const downNode = Color(0xFFF0876E);
  static const downNodeStrong = Color(0xFFE9745B);
  static const downNodeDeep = Color(0xFFE46850);
  static const downRing = Color(0xFFFFBCAB);

  static const peach = Color(0xFFFFB07C);
  static const peachDeep = Color(0xFFFF9B6A);
  static const peachShadow = Color(0xFFF08A55);
  static const peachBorder = Color(0xFFFFE0C2);
  static const peachInputBorder = Color(0xFFFFE3CD);
  static const peachText = Color(0xFFC89368);
  static const peachBlob = Color(0xFFFFE9D6);
  static const cheek = Color(0xFFFF9B8A);

  static const water = Color(0xFFDCEFFA);
  static const waterLine = Color(0xFF8ECAE6);
  static const waterRipple = Color(0xFFB5DCF2);
  static const waterLabel = Color(0xFF8BB8D0);
  static const waterBubble = Color(0xFFEAF6FF);
  static const waterBubbleStroke = Color(0xFF9FCBE8);
  static const seaweed = Color(0xFF9ED4B8);

  static const lavenderBlob = Color(0xFFF3E6FF);
  static const lavenderRing = Color(0xFFD3BCF0);
  static const lavenderText = Color(0xFF8A6FB0);
  static const rainyCloud = Color(0xFFECE6F2);
  static const rainyCloudStroke = Color(0xFFDDD3E8);
  static const rainyDrop = Color(0xFFA8C8FF);
  static const blueText = Color(0xFF5A82D6);

  static const sun = Color(0xFFFFD88A);
  static const sunStroke = Color(0xFFFFC95E);
  static const sunRay = Color(0xFFFFCF6E);
  static const cloud = Color(0xFFFAF1E3);

  static const frameOuter = Color(0xFF6B5A4D);
  static const frameInner = Color(0xFF54463B);
  static const statusText = Color(0xFF9A8576);
  static const neutralRing = Color(0xFFCFCFCF);
  static const neutralInk = Color(0xFF3A3A3A);

  static const backdropGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cream, surface],
  );

  static const upGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [matchaLight, matchaEnd],
  );

  static const downGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [downLight, down],
  );

  static const peachGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [peach, peachDeep],
  );
}
