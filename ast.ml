open Type

(* Interface des arbres abstraits *)
module type Ast =
sig
   type expression
   type instruction
   type fonction
   type programme
end


(* *************************************** *)
(* AST après la phase d'analyse syntaxique *)
(* *************************************** *)
module AstSyntax =
struct

(* Opérateurs unaires de Rat *)
type unaire = Numerateur | Denominateur

(* Opérateurs binaires de Rat *)
type binaire = Fraction | Plus | Mult | Equ | Inf

(* Affectables de Rat (identifiants ou déréférencements) *)
type affectable =
  (* Accès à un identifiant représenté par son nom *)
  | Ident of string
  (* Déréférencement d'un affectable *)
  | Deref of affectable

(* Arguments d'appel de fonction *)
type argument =
  | ArgNormal of expression  (* Passage par valeur *)
  | ArgRef of expression     (* Passage par référence *)

(* Expressions de Rat *)
and expression =
  (* Appel de fonction représenté par le nom de la fonction et la liste des paramètres réels *)
  | AppelFonction of string * argument list
  (* Affectable (remplace Ident) *)
  | Affectable of affectable
  (* Booléen *)
  | Booleen of bool
  (* Entier *)
  | Entier of int
  (* Valeur énumérée *)
  | IdentEnum of string
  (* Pointeur null *)
  | Null
  (* Allocation dynamique *)
  | New of typ
  (* Adresse d'une variable *)
  | Adresse of string
  (* Opération unaire représentée par l'opérateur et l'opérande *)
  | Unaire of unaire * expression
  (* Opération binaire représentée par l'opérateur, l'opérande gauche et l'opérande droite *)
  | Binaire of binaire * expression * expression

(* Instructions de Rat *)
type bloc = instruction list
and instruction =
  (* Déclaration de variable représentée par son type, son nom et l'expression d'initialisation *)
  | Declaration of typ * string * expression
  (* Affectation d'un affectable représenté par l'affectable et la nouvelle valeur affectée *)
  | Affectation of affectable * expression
  (* Déclaration d'une constante représentée par son nom et sa valeur (entier) *)
  | Constante of string * int
  (* Affichage d'une expression *)
  | Affichage of expression
  (* Conditionnelle représentée par la condition, le bloc then et le bloc else *)
  | Conditionnelle of expression * bloc * bloc
  (*Boucle TantQue représentée par la conditin d'arrêt de la boucle et le bloc d'instructions *)
  | TantQue of expression * bloc
  (* return d'une fonction (avec option pour les procédures) *)
  | Retour of expression option
  (* Appel de procédure comme instruction *)
  | AppelProc of string * argument list

(* Structure des fonctions de Rat *)
(* type de retour - nom - liste des paramètres (ref?, type, nom) - corps de la fonction *)
type fonction = Fonction of typ * string * (bool * typ * string) list * bloc

(* Déclaration d'un type énuméré *)
type enum_decl = string * string list

(* Structure d'un programme Rat *)
(* liste d'enums - liste de fonctions - programme principal *)
type programme = Programme of enum_decl list * fonction list * bloc

end


(* ********************************************* *)
(* AST après la phase d'analyse des identifiants *)
(* ********************************************* *)
module AstTds =
struct

  (* Affectables dans notre langage *)
  (* ~ affectable de l'AST syntaxique où les noms des identifiants ont été
  remplacés par les informations associées aux identificateurs *)
  type affectable =
    | Ident of Tds.info_ast (* le nom de l'identifiant est remplacé par ses informations *)
    | Deref of affectable

  (* Arguments d'appel de fonction *)
  type argument =
    | ArgNormal of expression  (* Passage par valeur *)
    | ArgRef of expression     (* Passage par référence - expression doit être un affectable *)

  (* Expressions existantes dans notre langage *)
  (* ~ expression de l'AST syntaxique où les noms des identifiants ont été
  remplacés par les informations associées aux identificateurs *)
  and expression =
    | AppelFonction of Tds.info_ast * argument list
    | Affectable of affectable (* remplace Ident *)
    | Booleen of bool
    | Entier of int
    | IdentEnum of Tds.info_ast
    | Null
    | New of typ
    | Adresse of Tds.info_ast  (* le nom de l'identifiant est remplacé par ses informations *)
    | Unaire of AstSyntax.unaire * expression
    | Binaire of AstSyntax.binaire * expression * expression

  (* instructions existantes dans notre langage *)
  (* ~ instruction de l'AST syntaxique où les noms des identifiants ont été
  remplacés par les informations associées aux identificateurs
  + suppression de nœuds (const) *)
  type bloc = instruction list
  and instruction =
    | Declaration of typ * Tds.info_ast * expression (* le nom de l'identifiant est remplacé par ses informations *)
    | Affectation of affectable * expression (* l'affectable remplace le nom de l'identifiant *)
    | Affichage of expression
    | Conditionnelle of expression * bloc * bloc
    | TantQue of expression * bloc
    | Retour of expression option * Tds.info_ast  (* les informations sur la fonction à laquelle est associé le retour *)
    | AppelProc of Tds.info_ast * argument list  (* Appel de procédure *)
    | Empty (* les nœuds ayant disparus: Const *)


  (* Structure des fonctions dans notre langage *)
  (* type de retour - informations associées à l'identificateur (dont son nom) - liste des paramètres (ref?, type, information) - corps de la fonction *)
  type fonction = Fonction of typ * Tds.info_ast * (bool * typ * Tds.info_ast) list * bloc

  (* Structure d'un programme dans notre langage *)
  (* Pas besoin de stocker les enums ici car ils sont déjà dans la TDS *)
  type programme = Programme of fonction list * bloc

end


(* ******************************* *)
(* AST après la phase de typage *)
(* ******************************* *)
module AstType =
struct

(* Opérateurs unaires de Rat - résolution de la surcharge *)
type unaire = Numerateur | Denominateur

(* Opérateurs binaires existants dans Rat - résolution de la surcharge *)
type binaire = Fraction | PlusInt | PlusRat | MultInt | MultRat | EquInt | EquBool | EquEnum | Inf

(* Affectables dans Rat *)
(* = affectable de AstTds *)
type affectable = AstTds.affectable

(* Arguments d'appel de fonction *)
type argument =
  | ArgNormal of expression  (* Passage par valeur *)
  | ArgRef of affectable     (* Passage par référence - doit être un affectable *)

(* Expressions existantes dans Rat *)
(* = expression de AstTds *)
and expression =
  | AppelFonction of Tds.info_ast * argument list
  | Affectable of affectable
  | Booleen of bool
  | Entier of int
  | IdentEnum of Tds.info_ast
  | Null
  | New of typ
  | Adresse of Tds.info_ast
  | Unaire of unaire * expression
  | Binaire of binaire * expression * expression

(* instructions existantes Rat *)
(* = instruction de AstTds + informations associées aux identificateurs, mises à jour *)
(* + résolution de la surcharge de l'affichage *)
type bloc = instruction list
 and instruction =
  | Declaration of Tds.info_ast * expression
  | Affectation of affectable * expression
  | AffichageInt of expression
  | AffichageRat of expression
  | AffichageBool of expression
  | Conditionnelle of expression * bloc * bloc
  | TantQue of expression * bloc
  | Retour of expression option * Tds.info_ast
  | AppelProc of Tds.info_ast * argument list
  | Empty (* les nœuds ayant disparus: Const *)

(* informations associées à l'identificateur (dont son nom), liste des paramètres, corps *)
type fonction = Fonction of Tds.info_ast * Tds.info_ast list * bloc

(* Structure d'un programme dans notre langage *)
type programme = Programme of fonction list * bloc

end

(* ******************************* *)
(* AST après la phase de placement *)
(* ******************************* *)
module AstPlacement =
struct

(* Affectables dans notre langage *)
(* = affectable de AstType *)
type affectable = AstType.affectable

(* Arguments d'appel de fonction *)
(* = argument de AstType *)
type argument = AstType.argument

(* Expressions existantes dans notre langage *)
(* = expression de AstType  *)
type expression = AstType.expression

(* instructions existantes dans notre langage *)
type bloc = instruction list * int (* taille du bloc *)
 and instruction =
 | Declaration of Tds.info_ast * expression
 | Affectation of affectable * expression
 | AffichageInt of expression
 | AffichageRat of expression
 | AffichageBool of expression
 | Conditionnelle of expression * bloc * bloc
 | TantQue of expression * bloc
 | Retour of expression option * int * int (* taille du retour et taille des paramètres *)
 | AppelProc of Tds.info_ast * argument list
 | Empty (* les nœuds ayant disparus: Const *)

(* informations associées à l'identificateur (dont son nom), liste de paramètres, corps, expression de retour *)
(* Plus besoin de la liste des paramètres mais on la garde pour les tests du placements mémoire *)
type fonction = Fonction of Tds.info_ast * Tds.info_ast list * bloc

(* Structure d'un programme dans notre langage *)
type programme = Programme of fonction list * bloc

end
