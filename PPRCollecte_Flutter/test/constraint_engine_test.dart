import 'package:flutter_test/flutter_test.dart';

import 'package:srm_collecte/services/constraint_engine.dart';

// Couvre les 4 patterns reels du Bloc 5 + quelques edge cases.
void main() {
  group('ConstraintRule.parseList', () {
    test('parse une liste valide', () {
      final rules = ConstraintRule.parseList(
        '[{"id":"r1","when":{"field":"x","eq":"a"},"action":"warn","message":"hi"}]',
      );
      expect(rules, hasLength(1));
      expect(rules.first.id, 'r1');
      expect(rules.first.action, ConstraintAction.warn);
    });

    test('tolere null / vide / JSON invalide', () {
      expect(ConstraintRule.parseList(null), isEmpty);
      expect(ConstraintRule.parseList(''), isEmpty);
      expect(ConstraintRule.parseList('[]'), isEmpty);
      expect(ConstraintRule.parseList('not json'), isEmpty);
    });
  });

  group('Contrainte 1 — Inaccessible : disable_others', () {
    final rules = ConstraintRule.parseList(
      '[{"id":"r1","when":{"field":"anomalie_regard","eq":"Inaccessible"},'
      '"action":"disable_others","except_fields":["anomalie_regard","geom"],'
      '"message":"Regard inaccessible"}]',
    );

    test('declenche le disable des autres champs', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'anomalie_regard': rules},
        values: {'anomalie_regard': 'Inaccessible'},
        allFields: ['anomalie_regard', 'geom', 'ep_profondeur', 'largeur'],
      );
      expect(result.disabledFields, {'ep_profondeur', 'largeur'});
      expect(result.disabledFields.contains('anomalie_regard'), isFalse);
      expect(result.disabledFields.contains('geom'), isFalse);
    });

    test('ne declenche pas pour une autre valeur', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'anomalie_regard': rules},
        values: {'anomalie_regard': 'Autre'},
        allFields: ['anomalie_regard', 'ep_profondeur'],
      );
      expect(result.disabledFields, isEmpty);
    });
  });

  group('Contrainte 2 — Tampons Scellés : disable_and_clear + side_effects', () {
    final rules = ConstraintRule.parseList(
      '[{"id":"r2","when":{"field":"anomalie_tamp","eq":"Tampons Scellés"},'
      '"action":"disable_and_clear","fields":["ep_profondeur","generatrice_supp"],'
      '"side_effects":[{"set_field":"retour_terrain","value":true}],'
      '"message":"Tampon scelle"}]',
    );

    test('grise ET vide les 2 champs cibles', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'anomalie_tamp': rules},
        values: {'anomalie_tamp': 'Tampons Scellés'},
        allFields: ['anomalie_tamp', 'ep_profondeur', 'generatrice_supp'],
      );
      expect(result.disabledFields, {'ep_profondeur', 'generatrice_supp'});
      expect(result.clearedFields, {'ep_profondeur', 'generatrice_supp'});
    });

    test('applique le side-effect retour_terrain=true', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'anomalie_tamp': rules},
        values: {'anomalie_tamp': 'Tampons Scellés'},
        allFields: ['anomalie_tamp', 'retour_terrain'],
      );
      expect(result.sideEffects, {'retour_terrain': true});
    });
  });

  group('Contrainte 3 — profondeur/generatrice hors [0,1] : warn', () {
    final rules = ConstraintRule.parseList(
      '[{"id":"r3","when":{"expr":"(ep_profondeur - generatrice_supp) < 0 || (ep_profondeur - generatrice_supp) > 1"},'
      '"requires_fields":["ep_profondeur","generatrice_supp"],"action":"warn",'
      '"fields":["ep_profondeur","generatrice_supp"],"message":"hors seuil"}]',
    );

    test('declenche si ecart = 1.5 (hors)', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'ep_profondeur': rules},
        values: {'ep_profondeur': 2.5, 'generatrice_supp': 1.0},
        allFields: ['ep_profondeur', 'generatrice_supp'],
      );
      expect(result.hasWarnings, isTrue);
      expect(result.warningsByField['ep_profondeur'], hasLength(1));
    });

    test('ne declenche pas si ecart = 0.5 (dans seuil)', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'ep_profondeur': rules},
        values: {'ep_profondeur': 1.5, 'generatrice_supp': 1.0},
        allFields: ['ep_profondeur', 'generatrice_supp'],
      );
      expect(result.hasWarnings, isFalse);
    });

    test('skippe si un des deux champs est null', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'ep_profondeur': rules},
        values: {'ep_profondeur': 10.0, 'generatrice_supp': null},
        allFields: ['ep_profondeur', 'generatrice_supp'],
      );
      expect(result.hasWarnings, isFalse);
    });
  });

  group('Contrainte 4 — largeur/longueur >= 5 : warn', () {
    final rules = ConstraintRule.parseList(
      '[{"id":"r4","when":{"field":"largeur",">=":5},"action":"warn",'
      '"fields":["largeur"],"message":"Largeur >= 5 m ({{largeur}} m)."}]',
    );

    test('declenche si largeur = 5 (inclusif)', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'largeur': rules},
        values: {'largeur': 5},
        allFields: ['largeur'],
      );
      expect(result.hasWarnings, isTrue);
      expect(result.allWarningMessages.first, contains('5 m'));
    });

    test('ne declenche pas si largeur = 4.9', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'largeur': rules},
        values: {'largeur': 4.9},
        allFields: ['largeur'],
      );
      expect(result.hasWarnings, isFalse);
    });

    test('accepte string castable en num', () {
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'largeur': rules},
        values: {'largeur': '6.5'},
        allFields: ['largeur'],
      );
      expect(result.hasWarnings, isTrue);
    });
  });

  group('Conditions composees', () {
    test('all : AND', () {
      final rules = ConstraintRule.parseList(
        '[{"id":"x","when":{"all":[{"field":"a","eq":"1"},{"field":"b","eq":"2"}]},'
        '"action":"warn","message":"ok"}]',
      );
      final values = {'a': '1', 'b': '2'};
      var result = ConstraintEngine.evaluate(
          rulesByPivotField: {'a': rules}, values: values, allFields: ['a', 'b']);
      expect(result.hasWarnings, isTrue);
      result = ConstraintEngine.evaluate(
          rulesByPivotField: {'a': rules},
          values: {'a': '1', 'b': '3'},
          allFields: ['a', 'b']);
      expect(result.hasWarnings, isFalse);
    });

    test('any : OR', () {
      final rules = ConstraintRule.parseList(
        '[{"id":"x","when":{"any":[{"field":"a","eq":"1"},{"field":"b","eq":"2"}]},'
        '"action":"warn","message":"ok"}]',
      );
      var result = ConstraintEngine.evaluate(
          rulesByPivotField: {'a': rules},
          values: {'a': '1', 'b': '99'},
          allFields: ['a', 'b']);
      expect(result.hasWarnings, isTrue);
      result = ConstraintEngine.evaluate(
          rulesByPivotField: {'a': rules},
          values: {'a': '0', 'b': '0'},
          allFields: ['a', 'b']);
      expect(result.hasWarnings, isFalse);
    });
  });

  group('Interpolation messages', () {
    test('{{field}} simple est remplace', () {
      final rules = ConstraintRule.parseList(
        '[{"id":"x","when":{"field":"largeur",">=":5},"action":"warn",'
        '"fields":["largeur"],"message":"largeur={{largeur}}"}]',
      );
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'largeur': rules},
        values: {'largeur': 6.5},
        allFields: ['largeur'],
      );
      expect(result.allWarningMessages.single, 'largeur=6.5');
    });

    test('{{expr}} arithmetique est evalue', () {
      final rules = ConstraintRule.parseList(
        '[{"id":"x","when":{"expr":"a + b > 10"},"action":"warn",'
        '"fields":["a"],"message":"somme={{a + b}}"}]',
      );
      final result = ConstraintEngine.evaluate(
        rulesByPivotField: {'a': rules},
        values: {'a': 7, 'b': 5},
        allFields: ['a', 'b'],
      );
      expect(result.allWarningMessages.single, 'somme=12');
    });
  });
}
