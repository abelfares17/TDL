# Implémentation des Pointeurs et du Passage par Référence

Ce document détaille toutes les modifications apportées au compilateur RAT pour implémenter :
1. **Les pointeurs** (allocation dynamique, déréférencement, adresse)
2. **Le passage par référence** (paramètres modifiables)

---

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Pointeurs](#pointeurs)
   - [Modifications du système de types](#1-modifications-du-système-de-types)
   - [Modifications de la grammaire](#2-modifications-de-la-grammaire)
   - [Modifications de l'AST](#3-modifications-de-last)
   - [Modifications des passes](#4-modifications-des-passes)
3. [Passage par référence](#passage-par-référence)
   - [Modifications de la TDS](#1-modifications-de-la-tds)
   - [Modifications de la grammaire](#2-modifications-de-la-grammaire-1)
   - [Modifications de l'AST](#3-modifications-de-last-1)
   - [Modifications des passes](#4-modifications-des-passes-1)
4. [Exemples de code](#exemples-de-code)
5. [Tests](#tests)

---

## Vue d'ensemble

### Pointeurs

Les pointeurs permettent :
- **Allocation dynamique** : `(new int)` alloue un entier sur le tas
- **Déréférencement** : `(*p)` accède à la valeur pointée
- **Adresse de variable** : `&x` obtient l'adresse d'une variable
- **Pointeur null** : `null` représente un pointeur invalide

### Passage par référence

Le passage par référence permet de modifier les variables passées en argument :
- **Déclaration** : `void f(ref int x)` - le paramètre `x` est passé par référence
- **Appel** : `f(ref myVar)` - le mot-clé `ref` doit aussi apparaître à l'appel
- **Validation** : Le compilateur vérifie la cohérence entre déclaration et appel

---

## Pointeurs

### 1. Modifications du système de types

**Fichier : [`type.ml`](../type.ml)**

#### Ajout du type Pointeur

```ocaml
type typ =
  | Bool
  | Int
  | Rat
  | Void
  | Undefined
  | Pointeur of typ    (* NOUVEAU : Type pointeur *)
  | Enum of string
```

**Explication** : Un pointeur est un type paramétré qui contient le type de la valeur pointée. Par exemple, `Pointeur Int` est un pointeur vers un entier.

#### Modification de getTaille

```ocaml
let rec getTaille t =
  match t with
  | Int -> 1
  | Bool -> 1
  | Rat -> 2
  | Pointeur _ -> 1      (* NOUVEAU : Un pointeur = 1 mot (adresse) *)
  | Enum _ -> 1
  | Undefined -> 0
  | Void -> 0
```

**Explication** : Un pointeur occupe 1 mot mémoire car c'est une adresse.

#### Modification de est_compatible

```ocaml
let rec est_compatible t1 t2 =
  match t1, t2 with
  | Bool, Bool -> true
  | Int, Int -> true
  | Rat, Rat -> true
  | Pointeur pt1, Pointeur pt2 -> est_compatible pt1 pt2  (* NOUVEAU *)
  | Pointeur _, Pointeur Undefined -> true                 (* null compatible *)
  | Pointeur Undefined, Pointeur _ -> true                 (* null compatible *)
  | Enum e1, Enum e2 -> e1 = e2
  | _ -> false
```

**Explication** :
- Deux pointeurs sont compatibles si leurs types pointés sont compatibles
- `null` (représenté par `Pointeur Undefined`) est compatible avec tout pointeur

#### Ajout de string_of_type

```ocaml
let rec string_of_type t =
  match t with
  | Bool -> "Bool"
  | Int -> "Int"
  | Rat -> "Rat"
  | Void -> "Void"
  | Undefined -> "Undefined"
  | Pointeur pt -> (string_of_type pt) ^ "*"   (* NOUVEAU *)
  | Enum nom -> "Enum " ^ nom
```

---

### 2. Modifications de la grammaire

**Fichier : [`parser.mly`](../parser.mly)**

#### Ajout des tokens

Aucun nouveau token nécessaire - les tokens `MULT`, `AMP`, `NULL`, `NEW` existaient déjà.

#### Modification de la règle `typ`

```ocaml
typ :
| BOOL       {Bool}
| INT        {Int}
| RAT        {Rat}
| VOID       {Void}
| n=TID      {Enum n}
| t=typ MULT {Pointeur t}    (* NOUVEAU : Type pointeur *)
```

**Explication** : On peut écrire `int*` pour un pointeur vers int, `int**` pour un pointeur vers pointeur, etc.

#### Modification de la règle `a` (affectable)

```ocaml
a :
| n=ID                    {Ident n}
| PO MULT aff=a PF        {Deref aff}    (* NOUVEAU : Déréférencement *)
```

**Explication** : `(*p)` est un affectable (on peut lire et écrire dedans).

#### Modification de la règle `e` (expression)

```ocaml
e :
| NULL                    {Null}           (* NOUVEAU : Pointeur null *)
| PO NEW t=typ PF         {New t}          (* NOUVEAU : Allocation *)
| AMP n=ID                {Adresse n}      (* NOUVEAU : Adresse de variable *)
| (* ... autres règles ... *)
```

**Explication** :
- `null` : littéral pour pointeur invalide
- `(new int)` : alloue un entier sur le tas
- `&x` : obtient l'adresse de la variable x

---

### 3. Modifications de l'AST

**Fichier : [`ast.ml`](../ast.ml)**

#### AstSyntax - Affectables

```ocaml
type affectable =
  | Ident of string
  | Deref of affectable    (* NOUVEAU : Déréférencement *)
```

**Explication** : Un déréférencement `(*p)` est récursif - on peut avoir `(* (* p))`.

#### AstSyntax - Expressions

```ocaml
type expression =
  | (* ... existantes ... *)
  | Null                    (* NOUVEAU *)
  | New of Type.typ         (* NOUVEAU *)
  | Adresse of string       (* NOUVEAU *)
```

#### AstTds - Affectables et Expressions

Les mêmes structures, mais avec `info_ast` au lieu de `string` :

```ocaml
type affectable =
  | Ident of Tds.info_ast
  | Deref of affectable

type expression =
  | (* ... *)
  | Null
  | New of Type.typ
  | Adresse of Tds.info_ast    (* info_ast au lieu de string *)
```

#### AstType et AstPlacement

Pas de changements structurels - propagation des mêmes types.

---

### 4. Modifications des passes

#### PasseTdsRat (Analyse identifiants)

**Fichier : [`passeTdsRat.ml`](../passeTdsRat.ml)**

##### Analyse des affectables

```ocaml
let rec analyse_tds_affectable tds a =
  match a with
  | AstSyntax.Ident s ->
      (* Vérifier que s existe et est une variable ou constante *)
      begin
        match chercherGlobalement tds s with
        | None -> raise (IdentifiantNonDeclare s)
        | Some info ->
            begin
              match info_ast_to_info info with
              | InfoVar _ -> AstTds.Ident info
              | InfoConst _ -> AstTds.Ident info
              | InfoFun _ -> raise (MauvaiseUtilisationIdentifiant s)
              | InfoEnum _ -> raise (MauvaiseUtilisationIdentifiant s)
              | InfoValeurEnum _ -> raise (MauvaiseUtilisationIdentifiant s)
            end
      end
  | AstSyntax.Deref aff ->
      (* NOUVEAU : Analyser récursivement le sous-affectable *)
      let naff = analyse_tds_affectable tds aff in
      AstTds.Deref naff
```

##### Analyse de l'adresse

```ocaml
| AstSyntax.Adresse n ->
    begin
      match chercherGlobalement tds n with
      | None -> raise (IdentifiantNonDeclare n)
      | Some info ->
          begin
            match info_ast_to_info info with
            | InfoVar _ -> AstTds.Adresse info    (* OK : variable *)
            | _ -> raise (MauvaiseUtilisationIdentifiant n)    (* Pas de &f ou &const *)
          end
    end
```

**Explication** : On ne peut prendre l'adresse que d'une variable, pas d'une fonction ou constante.

##### Analyse de null et new

```ocaml
| AstSyntax.Null ->
    AstTds.Null    (* Pas de vérification nécessaire *)

| AstSyntax.New t ->
    AstTds.New t   (* Le type est déjà résolu *)
```

#### PasseTypeRat (Vérification types)

**Fichier : [`passeTypeRat.ml`](../passeTypeRat.ml)**

##### Analyse des affectables

```ocaml
let rec analyse_type_affectable (a: AstTds.affectable) : typ * AstType.affectable =
  match a with
  | AstTds.Ident ia ->
      begin
        match info_ast_to_info ia with
        | InfoVar (_, t, _, _, _) -> (t, AstTds.Ident ia)
        | InfoConst (_, _) -> (Int, AstTds.Ident ia)
        | (* ... erreurs ... *)
      end
  | AstTds.Deref aff ->
      (* NOUVEAU : Vérifier que aff est un pointeur *)
      let (t_aff, naff) = analyse_type_affectable aff in
      begin
        match t_aff with
        | Pointeur t -> (t, AstTds.Deref naff)    (* Type pointé *)
        | _ -> raise (TypeInattendu (t_aff, Pointeur Undefined))
      end
```

**Explication** : Le déréférencement d'un `Pointeur t` retourne un affectable de type `t`.

##### Analyse des expressions

```ocaml
| AstTds.Null ->
    (* null est compatible avec tous les pointeurs *)
    (Pointeur Undefined, AstType.Null)

| AstTds.New t ->
    (* new TYPE retourne Pointeur TYPE *)
    (Pointeur t, AstType.New t)

| AstTds.Adresse ia ->
    begin
      match info_ast_to_info ia with
      | InfoVar (_, t, _, _, _) -> (Pointeur t, AstType.Adresse ia)
      | _ -> failwith "Adresse doit être associé à une variable"
    end
```

**Explication** :
- `null` : type `Pointeur Undefined` (polymorphe)
- `new int` : type `Pointeur Int`
- `&x` où `x: int` : type `Pointeur Int`

#### PassePlacementRat (Calcul offsets)

**Fichier : [`passePlacementRat.ml`](../passePlacementRat.ml)**

Pas de modifications majeures - les pointeurs ont une taille fixe (1 mot).

#### PasseCodeRat (Génération TAM)

**Fichier : [`passeCodeRat.ml`](../passeCodeRat.ml)**

##### Lecture d'un affectable

```ocaml
let rec analyse_code_affectable_lecture (a : AstPlacement.affectable) : string =
  match a with
  | AstTds.Ident ia ->
      load_ident ia
  | AstTds.Deref aff ->
      (* NOUVEAU : Déréférencement *)
      (* 1. Générer code pour obtenir l'adresse (pointeur) *)
      let c_aff = analyse_code_affectable_lecture aff in
      (* 2. Charger la valeur pointée avec LOADI *)
      c_aff ^ Tam.loadi 1
```

**Explication** :
1. `analyse_code_affectable_lecture aff` empile l'adresse (valeur du pointeur)
2. `LOADI 1` charge la valeur à cette adresse

**Exemple** : Pour `(*p)` où `p` est en `0[LB]` :
```tam
LOAD 1 0[LB]    ; Charger valeur de p (l'adresse)
LOADI 1         ; Charger valeur à cette adresse
```

##### Écriture dans un affectable

```ocaml
let analyse_code_affectable_ecriture (a : AstPlacement.affectable) (code_valeur : string) : string =
  match a with
  | AstTds.Ident ia ->
      code_valeur ^ store_var ia
  | AstTds.Deref aff ->
      (* NOUVEAU : Pour STOREI, on empile d'abord la valeur, puis l'adresse *)
      (* 1. Empiler la valeur *)
      let code_val = code_valeur in
      (* 2. Empiler l'adresse *)
      let c_aff = analyse_code_affectable_lecture aff in
      (* 3. STOREI *)
      code_val ^ c_aff ^ Tam.storei 1
```

**Explication** :
1. `code_valeur` empile la nouvelle valeur
2. `analyse_code_affectable_lecture aff` empile l'adresse
3. `STOREI 1` stocke la valeur à l'adresse

**Exemple** : Pour `(*p) = 42` où `p` est en `0[LB]` :
```tam
LOADL 42        ; Empiler valeur (42)
LOAD 1 0[LB]    ; Empiler adresse (valeur de p)
STOREI 1        ; Stocker 42 à l'adresse
```

##### Génération pour les expressions

```ocaml
| AstType.Null ->
    (* Représenter null comme 0 *)
    Tam.loadl_int 0

| AstType.New t ->
    (* Allocation : empiler taille puis appeler MAlloc *)
    Tam.loadl_int (getTaille t) ^ Tam.subr "MAlloc"

| AstType.Adresse ia ->
    begin
      match info_ast_to_info ia with
      | InfoVar (_, _, dep, reg, _) -> Tam.loada dep reg
      | _ -> failwith "Adresse doit être associé à une variable"
    end
```

**Explication** :
- `null` : empile 0 (convention pour adresse invalide)
- `new int` : empile 1 (taille), appelle `MAlloc` qui retourne l'adresse
- `&x` : `LOADA` charge l'adresse de x (pas sa valeur)

---

## Passage par référence

### 1. Modifications de la TDS

**Fichier : [`tds.ml`](../tds.ml)**

#### InfoVar - Ajout du flag is_ref

```ocaml
type info =
  | InfoConst of string * int
  | InfoVar of string * typ * int * string * bool
    (* nom, type, déplacement, registre, is_ref *)
  | InfoFun of string * typ * (bool * typ) list
    (* nom, type_retour, liste (is_ref, type) des paramètres *)
  | (* ... autres ... *)
```

**Explication** :
- `InfoVar` : le 5ème champ indique si c'est un paramètre passé par référence
- `InfoFun` : la signature contient pour chaque paramètre un couple `(is_ref, type)`

**Exemple** :
```ocaml
InfoFun ("swap", Void, [(true, Int); (true, Int)])
(* void swap(ref int a, ref int b) *)
```

---

### 2. Modifications de la grammaire

**Fichier : [`parser.mly`](../parser.mly)**

#### Ajout du type argument

```ocaml
%type <argument> arg
```

#### Règle pour les paramètres formels

```ocaml
param :
| t=typ n=ID          {(false, t, n)}    (* Paramètre normal *)
| REF t=typ n=ID      {(true, t, n)}     (* Paramètre ref *)
```

**Explication** : Un paramètre peut être marqué `ref` dans la déclaration.

#### Règle pour les arguments réels

```ocaml
arg :
| e=e           { ArgNormal e }     (* Passage par valeur *)
| REF e=e       { ArgRef e }        (* Passage par référence *)
```

**Explication** : Le mot-clé `ref` peut aussi apparaître à l'appel.

#### Utilisation dans les appels

```ocaml
e :
| n=ID PO lp=separated_list(VIRG, arg) PF   {AppelFonction (n, lp)}

i :
| n=ID PO lp=separated_list(VIRG, arg) PF PV  {AppelProc (n, lp)}
```

**Changement** : Au lieu de `separated_list(VIRG, e)`, on utilise `separated_list(VIRG, arg)`.

---

### 3. Modifications de l'AST

**Fichier : [`ast.ml`](../ast.ml)**

#### AstSyntax - Type argument

```ocaml
(* Arguments d'appel de fonction *)
type argument =
  | ArgNormal of expression  (* Passage par valeur *)
  | ArgRef of expression     (* Passage par référence *)
```

#### Modification des appels

```ocaml
type expression =
  | (* ... *)
  | AppelFonction of string * argument list    (* Changé : argument list *)

type instruction =
  | (* ... *)
  | AppelProc of string * argument list        (* Changé : argument list *)
```

#### AstTds - Type argument

```ocaml
type argument =
  | ArgNormal of expression
  | ArgRef of expression    (* Expression doit être un affectable *)
```

**Note** : Dans `ArgRef`, l'expression sera vérifiée pour être un affectable dans PasseTds.

#### AstType - Type argument

```ocaml
type argument =
  | ArgNormal of expression
  | ArgRef of affectable    (* Changé : affectable, pas expression *)
```

**Changement clé** : Dans AstType, `ArgRef` contient un `affectable` car seuls les affectables peuvent être passés par référence.

#### AstPlacement

```ocaml
type argument = AstType.argument    (* Alias *)
```

---

### 4. Modifications des passes

#### PasseTdsRat (Analyse identifiants)

**Fichier : [`passeTdsRat.ml`](../passeTdsRat.ml)**

##### Analyse des arguments

```ocaml
let rec analyser_tds_argument tds arg =
  match arg with
  | AstSyntax.ArgNormal e ->
      let ne = analyse_tds_expression tds e in
      AstTds.ArgNormal ne
  | AstSyntax.ArgRef e ->
      (* Vérifier que e est un affectable *)
      match e with
      | AstSyntax.Affectable aff ->
          let naff = analyser_tds_affectable tds aff in
          AstTds.ArgRef (AstTds.Affectable naff)
      | _ ->
          raise (MauvaiseUtilisationIdentifiant "ref")
```

**Explication** : Un argument `ref` doit être un affectable (variable, déréférencement). On ne peut pas faire `f(ref 42)`.

##### Modification des appels

```ocaml
| AstSyntax.AppelFonction (nom, args) ->
    (* ... chercher fonction ... *)
    let nargs = List.map (analyser_tds_argument tds) args in
    AstTds.AppelFonction (info, nargs)
```

##### Déclaration de fonction

```ocaml
let analyse_tds_fonction maintds (AstSyntax.Fonction (t, n, lp, li)) =
  (* lp : (bool * typ * string) list *)
  let nlp =
    List.map
      (fun (is_ref, tp, nom_param) ->
        (* ... vérifier pas de doublon ... *)
        let info_param = InfoVar (nom_param, Undefined, 0, "", is_ref) in
        let ia_param = info_to_info_ast info_param in
        ajouter tds_fonction nom_param ia_param;
        (is_ref, tp, ia_param)
      )
      lp
  in
  (* ... *)
```

**Explication** : Le flag `is_ref` est stocké dans l'`InfoVar` du paramètre.

#### PasseTypeRat (Vérification types)

**Fichier : [`passeTypeRat.ml`](../passeTypeRat.ml)**

##### Analyse des arguments

```ocaml
let rec analyse_type_argument arg =
  match arg with
  | AstTds.ArgNormal e ->
      let (t, ne) = analyse_type_expression e in
      (false, t, AstType.ArgNormal ne)
  | AstTds.ArgRef e ->
      (* e doit être un Affectable *)
      match e with
      | AstTds.Affectable aff ->
          let (t, naff) = analyse_type_affectable aff in
          (true, t, AstType.ArgRef naff)
      | _ ->
          failwith "Impossible : PasseTds devrait avoir vérifié"
```

**Retour** : `(bool * typ * AstType.argument)` où :
- `bool` : true si ref, false sinon
- `typ` : type de l'argument
- `AstType.argument` : argument typé

##### Validation des appels

```ocaml
| AstTds.AppelFonction (ia_fun, args) ->
    (* Analyser arguments *)
    let args_analyzed = List.map analyse_type_argument args in
    let args_ref_flags = List.map (fun (ref_flag, _, _) -> ref_flag) args_analyzed in
    let args_types = List.map (fun (_, t, _) -> t) args_analyzed in
    let nargs = List.map (fun (_, _, arg) -> arg) args_analyzed in

    (* Extraire signature de la fonction *)
    let params_ref_flags = List.map fst ltypes_params in
    let params_types = List.map snd ltypes_params in

    (* VALIDATION 0 : Nombre de paramètres *)
    if List.length args_types <> List.length params_types then
      raise (TypesParametresInattendus (args_types, params_types));

    (* VALIDATION 1 : Cohérence des flags ref *)
    if args_ref_flags <> params_ref_flags then
      raise (IncoherenceRefParametres (args_ref_flags, params_ref_flags));

    (* VALIDATION 2 : Compatibilité des types *)
    if est_compatible_list args_types params_types then
      (t_ret, AstType.AppelFonction (ia_fun, nargs))
    else
      raise (TypesParametresInattendus (args_types, params_types))
```

**Ordre des validations** :
1. **Nombre** : Vérifier que le nombre d'arguments correspond
2. **Ref** : Vérifier que les flags `ref` correspondent
3. **Types** : Vérifier la compatibilité des types

**Pourquoi cet ordre ?** Pour donner des messages d'erreur pertinents. Si le nombre est mauvais, on lève `TypesParametresInattendus` plutôt que `IncoherenceRefParametres` avec des listes de longueurs différentes.

#### PassePlacementRat (Calcul offsets)

**Fichier : [`passePlacementRat.ml`](../passePlacementRat.ml)**

##### Taille des paramètres

```ocaml
let taille_parametres_fonction ia =
  let params = types_parametres_fonction ia in
  List.fold_left (fun acc (is_ref, t) ->
    if is_ref then acc + 1         (* Paramètre ref = 1 mot (adresse) *)
    else acc + getTaille t         (* Paramètre normal = taille du type *)
  ) 0 params
```

**Explication** : Un paramètre `ref` occupe 1 mot (on passe une adresse), pas `getTaille t`.

##### Propagation des arguments

```ocaml
let rec analyser_placement_argument arg =
  match arg with
  | AstType.ArgNormal e ->
      let ne = analyser_placement_expression e in
      AstPlacement.ArgNormal ne
  | AstType.ArgRef aff ->
      let naff = analyser_placement_affectable aff in
      AstPlacement.ArgRef naff
```

#### PasseCodeRat (Génération TAM)

**Fichier : [`passeCodeRat.ml`](../passeCodeRat.ml)**

##### Chargement d'un paramètre ref

```ocaml
let load_ident ia =
  match info_ast_to_info ia with
  | InfoVar (_, t, dep, reg, is_ref) ->
      if is_ref then
        (* Paramètre ref : charger l'adresse puis déréférencer *)
        Tam.load 1 dep reg ^ Tam.loadi (getTaille t)
      else
        Tam.load (getTaille t) dep reg
  | (* ... *)
```

**Explication** :
- Paramètre normal : `LOAD <taille> <dep>[reg]` charge directement la valeur
- Paramètre ref : `LOAD 1 <dep>[reg]` charge l'adresse, puis `LOADI <taille>` déréférence

**Exemple** : Pour `x` où `x` est `ref int` en `-1[LB]` :
```tam
LOAD 1 -1[LB]    ; Charger l'adresse stockée
LOADI 1          ; Charger l'entier à cette adresse
```

##### Stockage dans un paramètre ref

```ocaml
let store_var ia =
  match info_ast_to_info ia with
  | InfoVar (_, t, dep, reg, is_ref) ->
      if is_ref then
        (* Paramètre ref : charger l'adresse puis stocker indirectement *)
        Tam.load 1 dep reg ^ Tam.storei (getTaille t)
      else
        Tam.store (getTaille t) dep reg
  | _ -> failwith "store_var: InfoVar attendu"
```

**Exemple** : Pour `x = 10` où `x` est `ref int` en `-1[LB]` :
```tam
LOADL 10         ; Valeur à stocker
LOAD 1 -1[LB]    ; Charger l'adresse
STOREI 1         ; Stocker via l'adresse
```

##### Passage d'arguments à l'appel

```ocaml
| AstType.AppelFonction (ia_fun, args) ->
    let params_info = types_parametres_fonction ia_fun in
    let code_args = String.concat "" (
      List.map2 (fun (is_ref_param, _) arg ->
        match arg with
        | AstType.ArgNormal e ->
            (* Type checker garantit cohérence *)
            if is_ref_param then failwith "IMPOSSIBLE";
            analyse_code_expression e
        | AstType.ArgRef aff ->
            if not is_ref_param then failwith "IMPOSSIBLE";
            (* Passer l'adresse de l'affectable *)
            match aff with
            | AstTds.Ident ia ->
                begin
                  match info_ast_to_info ia with
                  | InfoVar (_, _, dep, reg, is_ref_var) ->
                      if is_ref_var then
                        (* Variable déjà ref : passer sa valeur (qui est une adresse) *)
                        Tam.load 1 dep reg
                      else
                        (* Variable normale : passer son adresse *)
                        Tam.loada dep reg
                  | _ -> failwith "Doit être une variable"
                end
            | AstTds.Deref inner_aff ->
                (* Déréférencement : passer le pointeur lui-même *)
                analyse_code_affectable_lecture inner_aff
        ) params_info args
    ) in
    code_args ^ Tam.call "SB" (nom_fonction ia_fun)
```

**Explication détaillée** :

1. **ArgNormal** : Empiler la valeur normalement
   ```tam
   LOADL 42    ; Pour un littéral
   LOAD 1 0[LB] ; Pour une variable
   ```

2. **ArgRef avec variable normale** : Empiler l'adresse
   ```tam
   LOADA 1 0[LB]    ; Adresse de la variable
   ```

3. **ArgRef avec variable déjà ref** : Empiler l'adresse stockée
   ```tam
   LOAD 1 -1[LB]    ; Charger l'adresse (valeur du param ref)
   ```

4. **ArgRef avec déréférencement** : Empiler le pointeur
   ```tam
   LOAD 1 0[LB]    ; Si (*p), empiler valeur de p (qui est une adresse)
   ```

---

## Exemples de code

### Exemple 1 : Pointeurs simples

**Code RAT :**
```rat
main {
  int* p = (new int);
  (*p) = 42;
  print (*p);
}
```

**Code TAM généré :**
```tam
main
PUSH 1              ; Allouer espace pour p
LOADL 1             ; Taille à allouer
SUBR MAlloc         ; Allouer sur le tas
STORE 1 0[SB]       ; Stocker adresse dans p
LOADL 42            ; Valeur à stocker
LOAD 1 0[SB]        ; Charger adresse (valeur de p)
STOREI 1            ; Stocker 42 via pointeur
LOAD 1 0[SB]        ; Charger adresse
LOADI 1             ; Charger valeur pointée
SUBR IOut           ; Afficher
HALT
```

**Sortie :** `42`

---

### Exemple 2 : Adresse de variable

**Code RAT :**
```rat
main {
  int x = 10;
  int* p = &x;
  print (*p);
}
```

**Code TAM généré :**
```tam
main
PUSH 2              ; x (1) + p (1)
LOADL 10            ; Valeur de x
STORE 1 0[SB]       ; x = 10
LOADA 1 0[SB]       ; Adresse de x
STORE 1 1[SB]       ; p = &x
LOAD 1 1[SB]        ; Charger p (adresse)
LOADI 1             ; Charger *p
SUBR IOut           ; Afficher
HALT
```

**Sortie :** `10`

---

### Exemple 3 : Passage par référence simple

**Code RAT :**
```rat
void increment(ref int x) {
  x = (x+1);
}

main {
  int n = 5;
  increment(ref n);
  print n;
}
```

**Code TAM généré :**
```tam
increment
; Paramètre: ref int x en -1[LB]
LOAD 1 -1[LB]       ; Charger adresse
LOADI 1             ; Charger *x
LOADL 1
SUBR IAdd           ; x+1
LOAD 1 -1[LB]       ; Charger adresse
STOREI 1            ; *x = résultat
RETURN 0 1          ; Retour (0 valeur, 1 param)

main
PUSH 1              ; n
LOADL 5
STORE 1 0[SB]       ; n = 5
LOADA 1 0[SB]       ; Empiler &n
CALL SB increment   ; Appel
LOAD 1 0[SB]        ; Charger n
SUBR IOut           ; Afficher
HALT
```

**Sortie :** `6`

---

### Exemple 4 : Swap

**Code RAT :**
```rat
void swap(ref int a, ref int b) {
  int temp = a;
  a = b;
  b = temp;
}

main {
  int x = 1;
  int y = 4;
  swap(ref x, ref y);
  print x;
  print y;
}
```

**Code TAM généré :**
```tam
swap
; Paramètres: ref int a en -2[LB], ref int b en -1[LB]
; Variables locales: int temp en 3[LB]
PUSH 1              ; temp
LOAD 1 -2[LB]       ; Adresse de a
LOADI 1             ; *a
STORE 1 3[LB]       ; temp = a
LOAD 1 -1[LB]       ; Adresse de b
LOADI 1             ; *b
LOAD 1 -2[LB]       ; Adresse de a
STOREI 1            ; a = b
LOAD 1 3[LB]        ; temp
LOAD 1 -1[LB]       ; Adresse de b
STOREI 1            ; b = temp
POP 0 1             ; Libérer temp
RETURN 0 2          ; Retour (0 valeur, 2 params)

main
PUSH 2              ; x, y
LOADL 1
STORE 1 0[SB]       ; x = 1
LOADL 4
STORE 1 1[SB]       ; y = 4
LOADA 1 0[SB]       ; &x
LOADA 1 1[SB]       ; &y
CALL SB swap        ; Appel
LOAD 1 0[SB]
SUBR IOut           ; Afficher x
LOAD 1 1[SB]
SUBR IOut           ; Afficher y
HALT
```

**Sortie :** `14`

---

### Exemple 5 : Combinaison (pointeurs + ref)

**Code RAT :**
```rat
void allouer(ref int* p) {
  p = (new int);
  (*p) = 100;
}

main {
  int* ptr = null;
  allouer(ref ptr);
  print (*ptr);
}
```

**Explication** :
- `ptr` est un pointeur vers int, initialement null
- On passe `ptr` par référence à `allouer`
- `allouer` modifie `ptr` pour pointer vers un nouvel entier alloué
- `allouer` stocke 100 dans cet entier
- On affiche la valeur pointée par `ptr`

**Code TAM généré :**
```tam
allouer
; Paramètre: ref int* p en -1[LB]
LOADL 1             ; Taille à allouer
SUBR MAlloc         ; Allouer int
LOAD 1 -1[LB]       ; Adresse de p
STOREI 1            ; p = adresse allouée
LOADL 100           ; Valeur à stocker
LOAD 1 -1[LB]       ; Adresse de p
LOADI 1             ; Charger *p (adresse allouée)
STOREI 1            ; **p = 100
RETURN 0 1

main
PUSH 1              ; ptr
LOADL 0             ; null
STORE 1 0[SB]       ; ptr = null
LOADA 1 0[SB]       ; &ptr
CALL SB allouer     ; Appel
LOAD 1 0[SB]        ; Charger ptr
LOADI 1             ; Charger *ptr
SUBR IOut           ; Afficher
HALT
```

**Sortie :** `100`

---

## Tests

### Tests positifs (doivent compiler et s'exécuter)

#### Pointeurs
- ✅ `tests/tam/pointeurs/fichiersRat/alloc_deref.rat` - Allocation et déréférencement
- ✅ `tests/tam/pointeurs/fichiersRat/adresse_modif.rat` - Modification via pointeur

#### Passage par référence
- ✅ `tests/gestion_id/ref/fichiersRat/ref_simple.rat` - Fonction avec paramètre ref
- ✅ `tests/gestion_id/ref/fichiersRat/ref_mix.rat` - Mix ref/non-ref
- ✅ `tests/tam/ref/fichiersRat/ref_swap.rat` - Swap (page 4 du sujet)
- ✅ `tests/tam/ref/fichiersRat/ref_modif.rat` - Modification simple via ref

#### Intégration
- ✅ `tests/tam/integration/fichiersRat/combinaison.rat` - Programme complet combinant enum, pointeurs et ref
- ✅ `tests/tam/integration/fichiersRat/ref_pointeurs.rat` - Pointeurs passés par ref

### Tests négatifs (doivent échouer avec erreur spécifique)

#### Pointeurs
- ❌ `adresse_constante.rat` → `MauvaiseUtilisationIdentifiant` (pas de &const)
- ❌ `adresse_fonction.rat` → `MauvaiseUtilisationIdentifiant` (pas de &f)
- ❌ `deref_non_pointeur.rat` → `TypeInattendu` (déréférencement d'un non-pointeur)
- ❌ `affectation_pointeurs_incompatibles.rat` → `TypeInattendu` (int* ≠ rat*)

#### Passage par référence
- ❌ `ref_constante.rat` → `MauvaiseUtilisationIdentifiant` (pas de ref sur constante)
- ❌ `ref_type_incompatible.rat` → `TypesParametresInattendus` (mauvais type)
- ❌ Appel avec `ref` manquant → `IncoherenceRefParametres`
- ❌ Appel avec `ref` en trop → `IncoherenceRefParametres`

### Validation complète

```bash
# Compiler le projet
dune build

# Exécuter tous les tests
dune runtest

# Résultat attendu
# Tous les tests passent avec succès
```

---

## Instructions TAM utilisées

### Instructions existantes
- `LOAD size offset[reg]` - Charger valeur
- `STORE size offset[reg]` - Stocker valeur
- `LOADL n` - Charger constante
- `PUSH n` - Allouer sur pile
- `POP offset size` - Dépiler
- `CALL reg label` - Appel fonction
- `RETURN size_ret size_params` - Retour fonction

### Nouvelles instructions (pour pointeurs et ref)
- `LOADA size offset[reg]` - Charger **adresse** (pas valeur)
- `LOADI size` - Chargement **indirect** (déréférencement)
- `STOREI size` - Stockage **indirect** (via pointeur)
- `SUBR MAlloc` - Allocation dynamique sur tas

---

## Résumé

### Pointeurs

**Fichiers modifiés :**
- [`type.ml`](../type.ml) - Type `Pointeur`, compatibilité
- [`parser.mly`](../parser.mly) - Grammaire `null`, `new`, `&`, `(*)`
- [`ast.ml`](../ast.ml) - Constructeurs dans les 4 AST
- [`passeTdsRat.ml`](../passeTdsRat.ml) - Vérification identifiants
- [`passeTypeRat.ml`](../passeTypeRat.ml) - Typage et vérifications
- [`passeCodeRat.ml`](../passeCodeRat.ml) - Génération TAM avec LOADI/STOREI/LOADA/MAlloc

**Concepts clés :**
- Type `Pointeur t` paramétré par le type pointé
- `null` est `Pointeur Undefined` (polymorphe)
- Déréférencement vérifié au typage
- Code TAM utilise LOADI/STOREI pour accès indirect

### Passage par référence

**Fichiers modifiés :**
- [`tds.ml`](../tds.ml) - Flag `is_ref` dans InfoVar et InfoFun
- [`parser.mly`](../parser.mly) - Type `argument`, règles `arg`
- [`ast.ml`](../ast.ml) - Type `argument` dans les 4 AST
- [`exceptions.ml`](../exceptions.ml) - Exception `IncoherenceRefParametres`
- [`passeTdsRat.ml`](../passeTdsRat.ml) - Vérification affectables
- [`passeTypeRat.ml`](../passeTypeRat.ml) - Validation cohérence ref
- [`passePlacementRat.ml`](../passePlacementRat.ml) - Taille param ref = 1
- [`passeCodeRat.ml`](../passeCodeRat.ml) - Génération avec LOAD/LOADI pour accès

**Concepts clés :**
- Mot-clé `ref` requis à la déclaration ET à l'appel
- Validation en 3 étapes : nombre, ref, types
- Paramètre ref = 1 mot (adresse), accès via LOADI
- À l'appel : LOADA pour passer l'adresse

---

## Auteur

Ce document a été généré pour expliquer les modifications du compilateur RAT.
Date : 2026-01-15
