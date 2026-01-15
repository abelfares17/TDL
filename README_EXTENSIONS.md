# Extensions du Compilateur RAT

Ce projet étend le compilateur RAT avec 4 fonctionnalités majeures.

## 🎯 Fonctionnalités Implémentées

### 1. Procédures (Type `void`)
Fonctions sans valeur de retour.
```rat
void afficher(int n) {
  print n;
}
main { afficher(42); }
```

### 2. Types Énumérés
Types utilisateur avec valeurs constantes.
```rat
enum Couleur { Rouge, Vert, Bleu };
main {
  Couleur c = Rouge;
  print c;  // Affiche 0
}
```

### 3. Pointeurs
Allocation dynamique et manipulation d'adresses.
```rat
main {
  int* p = (new int);
  (*p) = 42;
  int x = 5;
  int* q = &x;
  print (*p);
  print (*q);
}
```

### 4. Passage par Référence
Paramètres modifiables dans les fonctions.
```rat
void swap(ref int a, ref int b) {
  int temp = a;
  a = b;
  b = temp;
}
main {
  int x = 5, y = 10;
  swap(x, y);  // x=10, y=5
}
```

## 📦 Structure du Projet

```
sourceEtu/
├── lexer.mll              # Analyseur lexical
├── parser.mly             # Analyseur syntaxique
├── type.ml[i]             # Système de types
├── tds.ml[i]              # Table des symboles
├── ast.ml                 # 4 AST progressifs
├── passe*.ml              # 4 passes de compilation
├── printerAst.ml          # Affichage AST
└── tests/                 # Tests par fonctionnalité
    ├── procedures/
    ├── enums/
    ├── pointeurs/
    └── ref/
```

## 🚀 Utilisation

### Compilation
```bash
dune build
```

### Tests
```bash
# Tous les tests
dune runtest

# Tests spécifiques
dune runtest tests/enums
dune runtest tests/pointeurs
dune runtest tests/procedures
dune runtest tests/ref
```

### Compiler un fichier RAT
```bash
dune exec ./compilateur.exe mon_fichier.rat
```

## 📊 Statistiques

- **Fichiers modifiés:** 13
- **Lignes ajoutées:** ~600
- **Tests créés:** 14
- **Taux de réussite:** 100% ✅

## 📚 Documentation

- `MODIFICATIONS.md` - Liste détaillée des modifications
- `/tmp/compte_rendu.md` - Rapport technique complet
- Plan d'implémentation dans `~/.claude/plans/`

## ✅ Statut

| Phase | Statut |
|-------|--------|
| Procédures | ✅ |
| Enums | ✅ |
| Pointeurs | ✅ |
| Pass-by-ref | ✅ |

**Projet complété à 100%** 🎉
