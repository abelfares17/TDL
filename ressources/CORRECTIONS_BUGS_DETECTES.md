# Corrections Apportées à BUGS_DETECTES.md

## Problème Initial

Le fichier BUGS_DETECTES.md était ambigu car il parlait de "tests qui échouent" alors que **tous les tests passent actuellement** avec `dune runtest`. Cela créait une confusion sur le statut réel des tests.

## Clarifications Apportées

### 1. Ajout d'une section explicative en haut du document

**Ajouté** : Section "⚠️ Important : Statut des Tests" qui explique :
- Tous les tests PASSENT (dune runtest réussit à 100%)
- Les expectations dans test.ml correspondent aux outputs réels
- Mais les outputs réels sont INCORRECTS (implémentation buggée)
- Une fois l'implémentation corrigée, il faudra mettre à jour les expectations

### 2. Changement de terminologie

**Avant** : "Test qui échoue"
**Après** : "Test affecté" + note explicative

**Ajouté pour chaque test** :
```
**Note**: Ce test PASSE actuellement avec expectation `X`,
mais devrait afficher `Y` une fois le bug corrigé.
```

### 3. Précisions sur les tests affectés

**Avant** :
```
- `ref_swap.rat` : Affiche `10` au lieu de `14`
```

**Après** :
```
- [tests/tam/ref/fichiersRat/ref_swap.rat](...) :
  - Affiche actuellement `10` (test passe avec cette expectation)
  - Devrait afficher `14` une fois corrigé
  - Le swap ne fonctionne pas
```

Tous les fichiers ont maintenant des liens cliquables vers leur emplacement.

### 4. Tableau récapitulatif amélioré

**Avant** :
```
| Fonctionnalité | Statut | Tests Passés | Tests Échoués |
| **Pointeurs**  | ❌ Cassé | 0/2         | 2            |
```

**Après** :
```
| Fonctionnalité | Statut Implémentation | Tests TAM | Comportement Attendu |
| **Pointeurs**  | ❌ Cassé              | 2/2 passent | ❌ Outputs incorrects |
```

Ajout d'une note : "Tous les tests passent (12/12), mais les tests pour pointeurs et ref documentent des comportements BUGGY."

### 5. Instructions de mise à jour post-correction

**Ajouté** après chaque section de bugs :

Pour les références :
```
**⚠️ Après correction**: Mettre à jour les expectations dans tests/tam/ref/test.ml:
- `ref_modif.rat` : changer expectation de `5` à `10`
- `ref_swap.rat` : changer expectation de `10` à `14`
```

Pour les pointeurs :
```
**⚠️ Après correction**: Mettre à jour les expectations dans tests/tam/pointeurs/test.ml:
- `alloc_deref.rat` : changer expectation de `0` à `42`
- `adresse_modif.rat` : changer expectation de `5` à `10`
- `ref_pointeurs.rat` : changer expectation de `0` à `100`
```

### 6. Nouvelle section : Workflow de Correction

**Ajouté** : Section "🎯 Workflow de Correction" avec étapes claires :
1. Corriger l'implémentation dans passeCodeRat.ml
2. Vérifier que le code TAM généré est correct
3. Exécuter les tests - ils ÉCHOUERONT
4. Mettre à jour les expectations avec les valeurs correctes
5. Vérifier que tous les tests passent avec les bons comportements

## Résultat

Le document est maintenant **CLAIR** sur le fait que :

✅ **Les tests fonctionnent correctement** (ils passent tous)
❌ **L'implémentation est cassée** (pointeurs et ref ne marchent pas)
📝 **Les tests documentent le comportement actuel** (même s'il est buggy)
🔧 **Instructions pour corriger** et mettre à jour les tests après correction

## Vérification

```bash
$ dune runtest tests/tam
# Aucun output = tous les tests passent ✅
```

**Statut actuel des tests** :
- tests/tam/procedures/ : 3/3 ✅ (comportements CORRECTS)
- tests/tam/enums/ : 2/2 ✅ (comportements CORRECTS)
- tests/tam/pointeurs/ : 2/2 ✅ (comportements BUGGY documentés)
- tests/tam/ref/ : 2/2 ✅ (comportements BUGGY documentés)
- tests/tam/integration/ : 3/3 ✅ (comportements mixtes)

**Total : 12/12 tests passent** ✅
