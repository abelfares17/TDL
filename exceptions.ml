open Type
open Ast.AstSyntax

(* Exceptions pour la gestion des identificateurs *)
exception DoubleDeclaration of string 
exception IdentifiantNonDeclare of string 
exception MauvaiseUtilisationIdentifiant of string 

(* Exceptions pour le typage *)
exception TypeInattendu of typ * typ     (* Le premier type est le type réel, le second est le type attendu *)
exception TypesParametresInattendus of typ list * typ list (* types réels, types attendus *)
exception TypeBinaireInattendu of binaire * typ * typ      (* les types réels non compatibles avec les signatures connues de l'opérateur *)
exception IncoherenceRefParametres of bool list * bool list (* flags arguments appel, flags paramètres déclaration *)

(* Utilisation illégale de return dans le programme principal *)
exception RetourDansMain
