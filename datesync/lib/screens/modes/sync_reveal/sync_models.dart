class SyncQuestion {
  final String promptEn;
  final String promptTr;
  final List<String> optionsEn;
  final List<String> optionsTr;

  final List<String> bonusEn;
  final List<String> bonusTr;

  final List<String> explainEn;
  final List<String> explainTr;

  const SyncQuestion({
    required this.promptEn,
    required this.promptTr,
    required this.optionsEn,
    required this.optionsTr,
    required this.bonusEn,
    required this.bonusTr,
    required this.explainEn,
    required this.explainTr,
  });
}
