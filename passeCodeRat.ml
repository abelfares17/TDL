open Tds
open Type
open Ast


type t1 = Ast.AstPlacement.programme
type t2 = string

(* ------------------------------------------------------- *)
(* Utilitaires TDS                                         *)
(* ------------------------------------------------------- *)

let nom_fonction ia =
  match info_ast_to_info ia with
  | InfoFun (n, _, _) -> n
  | _ -> failwith "nom_fonction: InfoFun attendu"

let types_parametres_fonction ia =
  match info_ast_to_info ia with
  | InfoFun (_, _, lt) -> lt
  | _ -> failwith "types_parametres_fonction: InfoFun attendu"

let taille_parametres_fonction ia =
  List.fold_left (fun acc t -> acc + getTaille t) 0 (types_parametres_fonction ia)

let load_ident ia =
  match info_ast_to_info ia with
  | InfoVar (_, t, dep, reg) ->
      Tam.load (getTaille t) dep reg
  | InfoConst (_, v) ->
      Tam.loadl_int v
  | InfoFun _ ->
      failwith "load_ident: identifiant de fonction utilisé comme expression"

let store_var ia =
  match info_ast_to_info ia with
  | InfoVar (_, t, dep, reg) ->
      Tam.store (getTaille t) dep reg
  | _ ->
      failwith "store_var: InfoVar attendu"

(* ------------------------------------------------------- *)
(* Analyse "retour garanti" (pour éviter return implicite) *)
(* ------------------------------------------------------- *)

let rec bloc_retour_garanti (li : AstPlacement.instruction list) : bool =
  match li with
  | [] -> false
  | i :: q ->
      if instr_retour_garanti i then true else bloc_retour_garanti q

and instr_retour_garanti (i : AstPlacement.instruction) : bool =
  match i with
  | AstPlacement.Retour _ -> true
  | AstPlacement.Conditionnelle (_, (bt,_), (be,_)) ->
      bloc_retour_garanti bt && bloc_retour_garanti be
  | AstPlacement.TantQue _ ->
      false
  | _ ->
      false

(* ------------------------------------------------------- *)
(* Génération code expressions                             *)
(* ------------------------------------------------------- *)

let rec analyse_code_expression (e : AstPlacement.expression) : string =
  match e with
  | AstType.Entier n ->
      Tam.loadl_int n

  | AstType.Booleen b ->
      Tam.loadl_int (if b then 1 else 0)

  | AstType.Ident ia ->
      load_ident ia

  | AstType.AppelFonction (ia_fun, args) ->
      let code_args = String.concat "" (List.map analyse_code_expression args) in
      code_args ^ Tam.call "SB" (nom_fonction ia_fun)

  | AstType.Unaire (op, e1) ->
      let ce = analyse_code_expression e1 in
      begin
        match op with
        | AstType.Numerateur ->
            (* rat = (num, den) sur la pile -> enlever den *)
            ce ^ Tam.pop 0 1
        | AstType.Denominateur ->
            (* garder den (top), enlever num (en dessous) *)
            ce ^ Tam.pop 1 1
      end

  | AstType.Binaire (op, e1, e2) ->
      let c1 = analyse_code_expression e1 in
      let c2 = analyse_code_expression e2 in
      begin
        match op with
        | AstType.Fraction ->
            c1 ^ c2 ^ Tam.call "SB" "norm"

        | AstType.PlusInt ->
            c1 ^ c2 ^ Tam.subr "IAdd"

        | AstType.MultInt ->
            c1 ^ c2 ^ Tam.subr "IMul"

        | AstType.PlusRat ->
            c1 ^ c2 ^ Tam.call "SB" "RAdd"

        | AstType.MultRat ->
            c1 ^ c2 ^ Tam.call "SB" "RMul"

        | AstType.EquInt ->
            c1 ^ c2 ^ Tam.subr "IEq"

        | AstType.EquBool ->
            c1 ^ c2 ^ Tam.subr "IEq"

        | AstType.Inf ->
            c1 ^ c2 ^ Tam.subr "ILss"
      end

(* ------------------------------------------------------- *)
(* Génération code instructions / blocs                    *)
(* ------------------------------------------------------- *)

let rec analyse_code_instruction (i : AstPlacement.instruction) : string =
  match i with
  | AstPlacement.Declaration (ia, e) ->
      analyse_code_expression e ^ store_var ia

  | AstPlacement.Affectation (ia, e) ->
      analyse_code_expression e ^ store_var ia

  | AstPlacement.AffichageInt e ->
      analyse_code_expression e ^ Tam.subr "IOut"

  | AstPlacement.AffichageRat e ->
      analyse_code_expression e ^ Tam.call "SB" "ROut"

  | AstPlacement.AffichageBool e ->
      analyse_code_expression e ^ Tam.subr "BOut"

  | AstPlacement.Conditionnelle (c, bthen, belse) ->
      let lelse = Code.getEtiquette () in
      let lend  = Code.getEtiquette () in
      analyse_code_expression c
      ^ Tam.jumpif 0 lelse
      ^ analyse_code_bloc ~pop_end:true bthen
      ^ Tam.jump lend
      ^ Tam.label lelse
      ^ analyse_code_bloc ~pop_end:true belse
      ^ Tam.label lend

  | AstPlacement.TantQue (c, b) ->
      let ldeb = Code.getEtiquette () in
      let lfin = Code.getEtiquette () in
      Tam.label ldeb
      ^ analyse_code_expression c
      ^ Tam.jumpif 0 lfin
      ^ analyse_code_bloc ~pop_end:true b
      ^ Tam.jump ldeb
      ^ Tam.label lfin

  | AstPlacement.Retour (e, taille_ret, taille_params) ->
      analyse_code_expression e ^ Tam.return taille_ret taille_params

  | AstPlacement.Empty ->
      ""

and analyse_code_bloc ~(pop_end : bool) ((li, taille) : AstPlacement.bloc) : string =
  let corps = String.concat "" (List.map analyse_code_instruction li) in
  let fin = if pop_end then Tam.pop 0 taille else "" in
  Tam.push taille ^ corps ^ fin

(* ------------------------------------------------------- *)
(* Fonctions et programme                                  *)
(* ------------------------------------------------------- *)

let analyse_code_fonction (AstPlacement.Fonction (ia_fun, _lparams, (li, taille) ) : AstPlacement.fonction) : string =
  let nom = nom_fonction ia_fun in
  let bloc = (li, taille) in
  let code_corps =
    Tam.label nom ^ analyse_code_bloc ~pop_end:false bloc
  in
  (* IMPORTANT :
     - pas de RETURN implicite (sinon testfun5 imprime 0)
     - si pas de retour garanti, on HALT pour éviter le fall-through *)
  if bloc_retour_garanti li then
    code_corps
  else
    code_corps ^ Tam.halt

let analyser (AstPlacement.Programme (fonctions, bloc_main) : t1) : t2 =
  let code_fcts = String.concat "" (List.map analyse_code_fonction fonctions) in
  let code_main =
    Tam.label "main"
    ^ analyse_code_bloc ~pop_end:false bloc_main
    ^ Tam.halt
  in
  Code.getEntete () ^ code_fcts ^ code_main