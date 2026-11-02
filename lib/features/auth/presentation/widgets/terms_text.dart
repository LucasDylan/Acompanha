import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/links.dart';

/// "[prefix]Termos de uso e a Política de privacidade.", with both documents
/// opening in an in-app browser.
class TermsText extends StatefulWidget {
  const TermsText({
    super.key,
    required this.prefix,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String prefix;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  State<TermsText> createState() => _TermsTextState();
}

class _TermsTextState extends State<TermsText> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => openLink(context, ApiConstants.termsUrl);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => openLink(context, ApiConstants.privacyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: AppColors.brand,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.brand,
    );
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: widget.prefix),
          TextSpan(text: 'Termos de uso', style: link, recognizer: _terms),
          const TextSpan(text: ' e a '),
          TextSpan(
            text: 'Política de privacidade',
            style: link,
            recognizer: _privacy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: widget.textAlign,
    );
  }
}
