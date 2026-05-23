import 'package:flutter/widgets.dart';

class StatsSemanticSection extends StatelessWidget {
  final Widget child;

  const StatsSemanticSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(container: true, explicitChildNodes: true, child: child);
  }
}

class StatsSemanticNode extends StatelessWidget {
  final String label;
  final String? value;
  final bool header;
  final Widget child;

  const StatsSemanticNode({
    super.key,
    required this.label,
    this.value,
    this.header = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      focusable: true,
      readOnly: true,
      header: header,
      label: label,
      value: value,
      child: ExcludeSemantics(child: child),
    );
  }
}
