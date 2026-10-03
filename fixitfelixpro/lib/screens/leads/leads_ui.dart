import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const leadsBrand = Color(0xFFF64C13);
const leadsPageBg = Color(0xFFF5F5F7);

/// Chrome every step of the application shares.
///
/// One widget rather than a Scaffold per screen so the progress bar, the
/// padding and the footer button cannot drift apart between steps — six
/// screens hand-assembling the same layout is six chances to get it slightly
/// wrong.
class LeadsStepScaffold extends StatelessWidget {
  const LeadsStepScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.actionLabel,
    this.onAction,
    this.footnote,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final Widget child;
  final String actionLabel;

  /// Null disables the button — the step is not finished.
  final VoidCallback? onAction;

  /// Shown above the button, usually saying what is still missing.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: leadsPageBg,
      appBar: AppBar(
        backgroundColor: leadsPageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        // Just the step count. Naming the journey here as well would put
        // "Verification" above a screen asking which trades somebody covers,
        // which is true but reads as a mistake — the intro already said what
        // this is.
        title: Text('Step $step of $totalSteps'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: step / totalSteps,
                minHeight: 3,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation(leadsBrand),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (footnote != null) ...[
                Text(
                  footnote!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: leadsBrand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    // From the theme, so the label keeps the app's font. A bare
                    // const TextStyle here carries fontFamily: null and renders
                    // in the platform default instead.
                    textStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white card of rows, matching the pro app's grouped lists.
class LeadsCard extends StatelessWidget {
  const LeadsCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class LeadsCaption extends StatelessWidget {
  const LeadsCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

/// A short note in the page's own voice — used for the things that are easy to
/// get wrong and expensive to discover late.
class LeadsNotice extends StatelessWidget {
  const LeadsNotice({
    super.key,
    required this.icon,
    required this.text,
    this.tone = LeadsNoticeTone.neutral,
  });

  final IconData icon;
  final String text;
  final LeadsNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      LeadsNoticeTone.neutral => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
      LeadsNoticeTone.warning => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      LeadsNoticeTone.locked => (const Color(0xFFF3F4F6), const Color(0xFF4B5563)),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

enum LeadsNoticeTone { neutral, warning, locked }

/// A labelled field inside a [LeadsCard].
class LeadsField extends StatelessWidget {
  const LeadsField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.suffix,
    this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              if (suffix != null) ...[
                const Spacer(),
                Text(
                  suffix!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            minLines: maxLines > 1 ? maxLines : null,
            onChanged: onChanged,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: Colors.black.withValues(alpha: 0.28),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class LeadsDivider extends StatelessWidget {
  const LeadsDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
      );
}

/// Ticked or not, used on the plan comparison and the review step.
class LeadsCheckLine extends StatelessWidget {
  const LeadsCheckLine({
    super.key,
    required this.text,
    required this.included,
  });

  final String text;
  final bool included;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included ? LucideIcons.check : LucideIcons.minus,
            size: 15,
            color: included ? const Color(0xFF059669) : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: included ? Colors.black87 : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
