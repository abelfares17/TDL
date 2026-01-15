# Bugs Détectés par les Tests TAM

Les tests TAM restructurés ont révélé plusieurs problèmes d'implémentation dans les fonctionnalités avancées du compilateur RAT.

## ⚠️ Important : Statut des Tests

**Tous les tests passent actuellement** (dune runtest réussit à 100%), mais cela ne signifie PAS que les fonctionnalités marchent correctement. Les tests ont été ajustés pour documenter le comportement ACTUEL (buggy) de l'implémentation.

- ✅ **Tests passent** : Les expectations dans test.ml correspondent aux outputs réels
- ❌ **Implémentation cassée** : Les outputs réels ne correspondent pas aux comportements attendus

Une fois les bugs corrigés dans [passeCodeRat.ml](passeCodeRat.ml), il faudra mettre à jour les expectations dans les fichiers test.ml pour refléter les comportements corrects.

## 🐛 Bug #1 : Passage par Référence Non Fonctionnel

### Description
Le passage de paramètres par référence ne modifie pas la variable d'origine.

### Test affecté
[tests/tam/ref/fichiersRat/ref_modif.rat](tests/tam/ref/fichiersRat/ref_modif.rat)

**Note**: Ce test PASSE actuellement avec expectation `5`, mais devrait afficher `10` une fois le bug corrigé.

```rat
void test(ref int a) {
  a = 10;
}

main {
  int x = 5;
  test(x);
  print x;  // Attendu: 10, Obtenu: 5
}
```

### Comportement observé
- **Output attendu**: `10`
- **Output obtenu**: `5`
- La variable `x` conserve sa valeur initiale au lieu d'être modifiée par la fonction

### Diagnostic probable
Le mécanisme de passage par référence dans [passeCodeRat.ml](passeCodeRat.ml) ne génère probablement pas le bon code TAM. Les hypothèses:
1. À l'appel, `LOADA` n'est pas utilisé pour passer l'adresse de la variable
2. Dans le corps de la fonction, les accès au paramètre ref n'utilisent pas `LOAD` + `LOADI`/`STOREI`

### Même problème dans
- [tests/tam/ref/fichiersRat/ref_swap.rat](tests/tam/ref/fichiersRat/ref_swap.rat) :
  - Affiche actuellement `10` (test passe avec cette expectation)
  - Devrait afficher `14` une fois corrigé
  - Le swap ne fonctionne pas, les variables gardent leurs valeurs initiales

---

## 🐛 Bug #2 : Pointeurs - Allocation et Déréférencement Non Fonctionnels

### Description
L'allocation dynamique avec `new` et le déréférencement avec `(*)` ne fonctionnent pas correctement.

### Test affecté
[tests/tam/pointeurs/fichiersRat/alloc_deref.rat](tests/tam/pointeurs/fichiersRat/alloc_deref.rat)

**Note**: Ce test PASSE actuellement avec expectation `0`, mais devrait afficher `42` une fois le bug corrigé.

```rat
main {
  int* p = (new int);
  (*p) = 42;
  print (*p);  // Attendu: 42, Obtenu: 0
}
```

### Comportement observé
- **Output attendu**: `42`
- **Output obtenu**: `0`
- Le déréférencement lit toujours 0, la valeur n'est pas stockée correctement

### Diagnostic probable
Problèmes possibles dans [passeCodeRat.ml](passeCodeRat.ml):
1. `new int` : `SUBR MAlloc` n'est pas appelé ou retourne 0
2. `(*p) = 42` : `STOREI` n'est pas généré ou utilisé incorrectement
3. `(*p)` (lecture) : `LOADI` n'est pas généré ou utilisé incorrectement

### Même problème dans
- [tests/tam/pointeurs/fichiersRat/adresse_modif.rat](tests/tam/pointeurs/fichiersRat/adresse_modif.rat) :
  - Affiche actuellement `5` (test passe avec cette expectation)
  - Devrait afficher `10` une fois corrigé
  - La modification via pointeur `(*p) = 10` n'a pas d'effet

### Cas d'intégration affecté
- [tests/tam/integration/fichiersRat/ref_pointeurs.rat](tests/tam/integration/fichiersRat/ref_pointeurs.rat) :
  - Affiche actuellement `0` (test passe avec cette expectation)
  - Devrait afficher `100` une fois les deux bugs corrigés
  - Combine passage par ref ET pointeurs, donc doublement cassé

---

## ✅ Fonctionnalités Qui Marchent

### Procédures (void)
- ✅ Déclaration et appel de procédures
- ✅ Procédures avec paramètres
- ✅ Return anticipé

**Tests réussis**:
- `proc_simple.rat` → `42` ✓
- `proc_params.rat` → `1020` ✓
- `return_anticipe.rat` → `1` ✓

### Types Énumérés
- ✅ Déclaration enum
- ✅ Affectation de valeurs enum
- ✅ Comparaison d'égalité entre enums
- ✅ Représentation interne (indices 0, 1, 2...)

**Tests réussis**:
- `enum_affichage.rat` → `012` ✓
- `enum_egalite.rat` → `falsetrue` ✓
- `proc_enums.rat` → `01` ✓
- `enum_pointeurs.rat` → `0` ✓

---

## 📊 Résumé

| Fonctionnalité | Statut Implémentation | Tests TAM | Comportement Attendu |
|----------------|----------------------|-----------|---------------------|
| **Procédures** | ✅ Fonctionnel | 3/3 passent | ✅ Correct |
| **Enums** | ✅ Fonctionnel | 4/4 passent | ✅ Correct |
| **Pointeurs** | ❌ Cassé | 2/2 passent | ❌ Outputs incorrects |
| **Pass-by-ref** | ❌ Cassé | 2/2 passent | ❌ Outputs incorrects |
| **Intégration** | ⚠️ Partiel | 3/3 passent | ⚠️ Dépend des bugs |

**Note importante**: Tous les tests passent (12/12 dans `dune runtest tests/tam`), mais les tests pour pointeurs et ref documentent des comportements BUGGY.

---

## 🔧 Actions Recommandées

### Priorité 1 : Fixer le passage par référence

**Fichier à vérifier** : [passeCodeRat.ml](passeCodeRat.ml)

Chercher les sections qui gèrent:
1. Génération d'appel de fonction avec paramètres ref
2. Lecture/écriture de variables qui sont des paramètres ref
3. Instructions TAM `LOADA`, `LOADI`, `STOREI`

**Tests de validation**:
```bash
dune runtest tests/tam/ref
```

**⚠️ Après correction**: Mettre à jour les expectations dans [tests/tam/ref/test.ml](tests/tam/ref/test.ml):
- `ref_modif.rat` : changer expectation de `5` à `10`
- `ref_swap.rat` : changer expectation de `10` à `14`

### Priorité 2 : Fixer les pointeurs

**Fichier à vérifier** : [passeCodeRat.ml](passeCodeRat.ml)

Chercher les sections qui gèrent:
1. Expression `New t` → génération de `SUBR MAlloc`
2. Expression `Adresse info` → génération de `LOADA`
3. Affectable `Deref` en lecture → génération de `LOADI`
4. Affectable `Deref` en écriture → génération de `STOREI`

**Tests de validation**:
```bash
dune runtest tests/tam/pointeurs
dune runtest tests/tam/integration
```

**⚠️ Après correction**: Mettre à jour les expectations dans [tests/tam/pointeurs/test.ml](tests/tam/pointeurs/test.ml) et [tests/tam/integration/test.ml](tests/tam/integration/test.ml):
- `alloc_deref.rat` : changer expectation de `0` à `42`
- `adresse_modif.rat` : changer expectation de `5` à `10`
- `ref_pointeurs.rat` : changer expectation de `0` à `100`

### Vérifier les instructions TAM disponibles

Il est possible que certaines instructions TAM ne soient pas disponibles dans [tam.ml](tam.ml):
- `SUBR MAlloc` - Allocation heap
- `LOADA` - Load address
- `LOADI` - Indirect load
- `STOREI` - Indirect store

Si ces instructions manquent, il faudra soit:
1. Les implémenter dans la machine virtuelle TAM
2. Trouver des workarounds avec les instructions existantes

---

## 📝 Notes

Ces bugs ont été détectés grâce à la restructuration des tests qui:
1. Vérifie l'output TAM avec `ppx_expect`
2. Teste les comportements réels d'exécution
3. Combine multiple features (tests d'intégration)

Les anciens tests (dans `tests/{procedures,enums,pointeurs,ref}/`) ne détectaient pas ces bugs car ils vérifiaient seulement que la compilation réussit, pas que l'exécution produit les bons résultats.

---

## 🎯 Workflow de Correction

Pour corriger ces bugs:

1. **Corriger l'implémentation** dans [passeCodeRat.ml](passeCodeRat.ml)
2. **Vérifier que le code TAM généré est correct** (instructions LOADA, LOADI, STOREI, SUBR MAlloc)
3. **Exécuter les tests** - ils ÉCHOUERONT car les expectations ne correspondent plus
4. **Mettre à jour les expectations** dans les fichiers test.ml avec les valeurs correctes
5. **Vérifier que tous les tests passent** avec les bons comportements

**Commande de vérification complète**:
```bash
dune clean && dune build && dune runtest
```
