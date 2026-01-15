# Liste des Modifications - Compilateur RAT Étendu

## Résumé Exécutif

✅ **5 phases complétées** | 🔧 **13 fichiers modifiés** | 🧪 **14 tests** | ✨ **~600 lignes ajoutées**

---

## Modifications par Fichier

### 1. [lexer.mll](lexer.mll)
**Rôle:** Analyse lexicale - Transformer le texte en tokens

**Modifications:**
```ocaml
+ "enum"  → ENUM      // Types énumérés
+ "null"  → NULL      // Pointeur null
+ "new"   → NEW       // Allocation heap
+ "ref"   → REF       // Passage par référence
+ "&"     → AMP       // Opérateur adresse
+ TID token           // Identifiants majuscules (enums)
```

---

### 2. [parser.mly](parser.mly)
**Rôle:** Analyse syntaxique - Construire l'AST

**Modifications:**
```ocaml
+ enum_decl: ENUM nom=TID AO vals=list(TID) AF PV
+ typ: ... | t=typ MULT    // TYPE*
+ param: typ ID | REF typ ID
+ e: ... | NULL | (NEW typ) | AMP id | TID
```

**Impact:** Grammaire étendue pour 4 nouvelles fonctionnalités

---

### 3. [type.ml](type.ml) + [type.mli](type.mli)
**Rôle:** Système de types du langage

**Modifications:**
```ocaml
type typ = 
  | Bool | Int | Rat 
  | Void              // ← Nouveau (procédures)
  | Enum of string    // ← Nouveau (enums)
  | Pointeur of typ   // ← Nouveau (pointeurs)
  | Undefined

+ getTaille: Void→0, Enum→1, Pointeur→1
+ est_compatible: 
    - Enum n1, Enum n2 → n1 = n2
    - Pointeur _, Pointeur Undefined → true (null)
    - Pointeur t1, Pointeur t2 → recursive check
+ string_of_type: récursif pour Pointeur
```

**Impact:** 3 nouveaux types, compatibilité étendue

---

### 4. [tds.ml](tds.ml) + [tds.mli](tds.mli)
**Rôle:** Table des symboles (informations sur identifiants)

**Modifications:**
```ocaml
type info =
  | InfoConst of string * int
  | InfoVar of string * typ * int * string * bool
    //                                      ↑ Nouveau: is_ref
  | InfoFun of string * typ * (bool * typ) list
    //                          ↑ Nouveau: ref flags
  | InfoEnum of string * string list         // ← Nouveau
  | InfoValeurEnum of string * string * int  // ← Nouveau

+ string_of_info: affichage avec (ref) et enums
+ Fonctions de modification: préserver is_ref
```

**Impact:** 2 nouveaux constructeurs, InfoVar/InfoFun étendus

---

### 5. [ast.ml](ast.ml)
**Rôle:** Définition des 4 AST (Syntax, Tds, Type, Placement)

**Modifications:**

**AstSyntax:**
```ocaml
type expression = ... 
  | IdentEnum of string        // ← Nouveau
  | Null                       // ← Nouveau
  | New of typ                 // ← Nouveau
  | Adresse of string          // ← Nouveau

type instruction = ...
  | Retour of expression option  // option pour void

type fonction = Fonction of 
  typ * string * (bool*typ*string) list * bloc
  //              ↑ Nouveau: ref flags

type enum_decl = string * string list  // ← Nouveau
type programme = Programme of 
  enum_decl list * fonction list * bloc
```

**AstTds:** Propagation avec info_ast
**AstType:** Propagation identique
**AstPlacement:** Inchangé (réutilise AstType)

---

### 6. [printerAst.ml](printerAst.ml)
**Rôle:** Affichage des AST (debug/test)

**Modifications:**
```ocaml
+ string_of_expression:
    | IdentEnum n → n
    | Null → "null"
    | New t → "(new "^type^")"
    | Adresse n → "&"^n

+ string_of_fonction:
    paramètres avec "ref" prefix si is_ref

+ string_of_programme:
    affichage enums
```

---

### 7. [passeTdsRat.ml](passeTdsRat.ml)
**Rôle:** Passe 1 - Analyse identifiants, construction TDS

**Modifications:**
```ocaml
+ analyse_tds_enum(tds, (nom, valeurs)):
    - Ajouter InfoEnum(nom, valeurs)
    - Pour chaque valeur i: InfoValeurEnum(val, nom, i)

+ analyse_tds_expression:
    | IdentEnum → vérifier InfoValeurEnum
    | Null → passer tel quel
    | New t → passer tel quel  
    | Adresse n → vérifier InfoVar uniquement

+ analyse_tds_fonction:
    - Extraire (is_ref, typ, nom) des paramètres
    - Créer InfoVar(..., is_ref) pour chaque param
    - InfoFun avec (is_ref, typ) list
```

**Impact:** Gestion complète enums + pointeurs + ref dans TDS

---

### 8. [passeTypeRat.ml](passeTypeRat.ml)
**Rôle:** Passe 2 - Vérification des types

**Modifications:**
```ocaml
+ analyse_type_affectable:
    | Deref aff → vérifier Pointeur, extraire type pointé

+ analyse_type_expression:
    | IdentEnum ia → (Enum nom_type, ...)
    | Null → (Pointeur Undefined, ...)
    | New t → (Pointeur t, ...)
    | Adresse ia → (Pointeur t_var, ...)

+ Binaire Equ:
    - Si Enum: EquEnum
    - Si Pointeur: EquInt (comparaison adresses)

+ Affichage:
    - Enum → AffichageInt
    - Pointeur → AffichageInt

+ analyse_type_fonction:
    - Vérifier void ↔ return None
    - Extraire types depuis (bool * typ) list
    - Vérifier compatibilité params

+ AppelFonction/AppelProc:
    - Comparer avec List.map snd ltypes_params
```

**Impact:** Type checking complet pour 4 fonctionnalités

---

### 9. [passePlacementRat.ml](passePlacementRat.ml)
**Rôle:** Passe 3 - Allocation mémoire (déplacements)

**Modifications:**
```ocaml
+ Calcul taille paramètres:
    if is_ref then 1 else getTaille t

+ Placement paramètres:
    taille = if is_ref then 1 else getTaille t
    
// Enums: déjà 1 via getTaille
// Pointeurs: déjà 1 via getTaille
// Void: déjà 0 via getTaille
```

**Impact:** Paramètres ref = 1 mot (adresse)

---

### 10. [passeCodeRat.ml](passeCodeRat.ml)
**Rôle:** Passe 4 - Génération code TAM

**Modifications:**
```ocaml
+ load_ident:
    if is_ref then 
      LOAD 1 dep reg; LOADI (getTaille t)
    else LOAD (getTaille t) dep reg

+ store_var:
    if is_ref then
      LOAD 1 dep reg; STOREI (getTaille t)
    else STORE (getTaille t) dep reg

+ analyse_code_affectable_lecture (Deref):
    charge_adresse; LOADI 1

+ analyse_code_affectable_ecriture (Deref):
    charge_adresse; valeur; STOREI 1

+ analyse_code_expression:
    | IdentEnum ia → LOADL index
    | Null → LOADL 0
    | New t → LOADL (getTaille t); SUBR MAlloc
    | Adresse ia → LOADA dep reg
    
+ AppelFonction:
    Pour chaque arg:
      if param is_ref then LOADA
      else évaluer expression
```

**Impact:** Génération code pour enums/pointeurs/ref

---

### 11. [passe.ml](passe.ml)
**Rôle:** Infrastructure des passes

**Modifications:**
```ocaml
// Pattern matching étendu
- InfoVar (n,_,d,r)
+ InfoVar (n,_,d,r,_)  // 5ème champ = is_ref
```

---

## Tests Créés

### Structure
```
tests/
├── procedures/    (4 tests) - Phase 2
├── enums/        (4 tests) - Phase 3
├── pointeurs/    (4 tests) - Phase 4
└── ref/          (2 tests) - Phase 5
```

Chaque répertoire contient:
- `test.ml` - Tests unitaires avec ppx_inline_test
- `dune` - Configuration build
- `fichiersRat/*.rat` - Fichiers sources à compiler

---

## Instructions TAM Utilisées

### Existantes étendues
- `LOAD/STORE` - Variables normales et paramètres ref
- `LOADL` - Null, indices enums
- `SUBR IEq` - Égalité enums et pointeurs

### Nouvelles utilisations
- `LOADA` - Charger adresse (&var, appel ref)
- `LOADI` - Déréférencer pointeur (*p lecture)
- `STOREI` - Écrire via pointeur (*p écriture)
- `SUBR MAlloc` - Allocation heap (new)

---

## Commandes de Test

```bash
# Build complet
dune build

# Tests spécifiques
dune runtest tests/enums
dune runtest tests/pointeurs  
dune runtest tests/procedures
dune runtest tests/ref

# Tous les tests
dune runtest

# Nettoyage
dune clean
```

---

## Statut Final

| Aspect | Statut |
|--------|--------|
| Compilation | ✅ Réussie |
| Tests | ✅ 14/14 passent |
| Warnings | ⚠️ 3 mineurs (unused) |
| Erreurs | ✅ Aucune |
| Couverture | ✅ 100% des phases |

**Projet finalisé et opérationnel** 🎉
