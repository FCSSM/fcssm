class ResultatImportFirebase {
  final int ajoutes;
  final int modifies;
  final int inchanges;

  const ResultatImportFirebase({
    required this.ajoutes,
    required this.modifies,
    required this.inchanges,
  });

  int get total => ajoutes + modifies + inchanges;
}