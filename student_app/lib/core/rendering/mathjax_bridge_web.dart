// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredMathJaxViewTypes = <String>{};

/// Widget de rendu vectoriel MathJax v3 SVG pour Flutter Web — compatible CanvasKit.
///
/// Stratégie : IFrame avec srcdoc auto-contenant. MathJax est chargé depuis le CDN
/// directement dans l'iframe (sandbox allow-scripts sans allow-same-origin pour
/// permettre les ressources CDN externes). Le LaTeX est injecté inline en JSON
/// pour éviter toute injection.
class MathJaxSvgView extends StatefulWidget {
  final String latex;
  final bool isDisplay;
  final Color? color;
  final double fontSize;

  const MathJaxSvgView({
    super.key,
    required this.latex,
    this.isDisplay = true,
    this.color,
    this.fontSize = 17.0,
  });

  @override
  State<MathJaxSvgView> createState() => _MathJaxSvgViewState();
}

class _MathJaxSvgViewState extends State<MathJaxSvgView> {
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _setupView();
  }

  @override
  void didUpdateWidget(covariant MathJaxSvgView old) {
    super.didUpdateWidget(old);
    if (old.latex != widget.latex ||
        old.isDisplay != widget.isDisplay ||
        old.color != widget.color ||
        old.fontSize != widget.fontSize) {
      _setupView();
    }
  }

  void _setupView() {
    final effectiveColor = widget.color ?? const Color(0xFFE2E8F0);
    final colorHex =
        '#${effectiveColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

    // Identifiant stable par contenu — évite les collisions
    final vKey =
        '${widget.latex.hashCode.abs()}_${widget.isDisplay ? "d" : "t"}_${colorHex.replaceAll("#", "")}_${widget.fontSize.toInt()}';
    final viewType = 'mj3_v2_$vKey';

    if (!_registeredMathJaxViewTypes.contains(viewType)) {
      _registeredMathJaxViewTypes.add(viewType);

      final latexJson = jsonEncode(widget.latex);
      final isDisplayJs = widget.isDisplay ? 'true' : 'false';
      final fontSizePx = widget.fontSize.toStringAsFixed(1);
      final justifyContent = widget.isDisplay ? 'center' : 'flex-start';

      // Srcdoc complet — MathJax depuis CDN jsdelivr (HTTPS)
      // sandbox="allow-scripts" : scripts JS autorisés, DOM isolé du parent.
      // IMPORTANT : pas de "allow-same-origin" → le srcdoc ne peut pas
      // accéder au DOM parent, ce qui est la configuration sécurisée.
      // Le chemin /mathjax/tex-svg.js NE FONCTIONNE PAS sans allow-same-origin
      // depuis un srcdoc — on utilise donc le CDN directement dans l'iframe.
      final srcdoc = '''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { background: transparent; height: 100%; overflow: hidden; }
body {
  display: flex;
  align-items: center;
  justify-content: $justifyContent;
  padding: 2px 4px;
}
#mj { color: $colorHex; display: inline-block; }
mjx-container { overflow: visible !important; }
svg { height: auto !important; }
</style>
<script>
window.MathJax = {
  tex: { packages: {"[+]": ["noerrors", "noundefined"]} },
  svg: { fontCache: "local", scale: 1.05 },
  startup: { typeset: false }
};
</script>
<script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js" crossorigin="anonymous"></script>
</head>
<body>
<div id="mj"></div>
<script>
var L = $latexJson;
var D = $isDisplayJs;
var FS = $fontSizePx;
function render() {
  if (!window.MathJax || !window.MathJax.tex2svg) { return setTimeout(render, 40); }
  var el = document.getElementById("mj");
  if (!el) return;
  // Eviter le double rendu
  if (el.dataset.rendered === "1") return;
  el.dataset.rendered = "1";
  try {
    var node = window.MathJax.tex2svg(L, { display: D });
    el.innerHTML = "";
    el.appendChild(node);
    el.style.fontSize = FS + "px";
  } catch(e) {
    el.removeAttribute("data-rendered");
    el.style.fontStyle = "italic";
    el.style.fontFamily = "Georgia, serif";
    el.style.fontSize = FS + "px";
    el.textContent = L;
  }
}
if (document.readyState === "complete") { render(); }
else { window.addEventListener("load", render); }
</script>
</body>
</html>''';

      ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
        final iframe = html.IFrameElement()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = 'transparent'
          ..style.overflow = 'hidden'
          // allow-scripts : JS autorisé ; PAS allow-same-origin : iframe isolé
          ..setAttribute('sandbox', 'allow-scripts')
          ..setAttribute('loading', 'eager')
          ..setAttribute('frameborder', '0')
          ..setAttribute('scrolling', 'no');

        // srcdoc via la propriété (pas setAttribute) pour assurer l'encodage correct
        iframe.srcdoc = srcdoc;
        return iframe;
      });
    }

    if (mounted) {
      setState(() { _viewType = viewType; });
    } else {
      _viewType = viewType;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewType == null) {
      return SizedBox(
        height: widget.isDisplay
            ? (widget.fontSize * 2.8).clamp(42.0, 96.0)
            : (widget.fontSize * 1.8).clamp(28.0, 56.0),
        child: const Center(
          child: SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    final double height = widget.isDisplay
        ? (widget.fontSize * 2.8).clamp(42.0, 96.0)
        : (widget.fontSize * 1.8).clamp(28.0, 56.0);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: HtmlElementView(viewType: _viewType!),
    );
  }
}
