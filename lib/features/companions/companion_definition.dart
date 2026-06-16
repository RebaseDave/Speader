class CompanionDefinition {
  final int slot;
  final String name;
  final String assetKey; // z.B. 'assets/companions/owl.png'

  const CompanionDefinition({
    required this.slot,
    required this.name,
    required this.assetKey,
  });

  static const List<CompanionDefinition> all = [
    CompanionDefinition(slot: 1, name: 'Luna', assetKey: 'companions/luna'),
    CompanionDefinition(slot: 2, name: 'Dex', assetKey: 'companions/dex'),
    CompanionDefinition(slot: 3, name: 'Embra', assetKey: 'companions/embra'),
    CompanionDefinition(slot: 4, name: 'Fena', assetKey: 'companions/fena'),
    CompanionDefinition(
      slot: 5,
      name: 'Florina',
      assetKey: 'companions/florina',
    ),
    CompanionDefinition(slot: 6, name: 'Glacis', assetKey: 'companions/glacis'),
    CompanionDefinition(slot: 7, name: 'Kiran', assetKey: 'companions/kiran'),
    CompanionDefinition(slot: 8, name: 'Merlin', assetKey: 'companions/merlin'),
    CompanionDefinition(slot: 9, name: 'Morvis', assetKey: 'companions/morvis'),
    CompanionDefinition(
      slot: 10,
      name: 'Aldric',
      assetKey: 'companions/aldric',
    ),
    CompanionDefinition(slot: 11, name: 'Tidan', assetKey: 'companions/tidan'),
  ];

  static CompanionDefinition forSlot(int slot) =>
      all.firstWhere((d) => d.slot == slot);
}
