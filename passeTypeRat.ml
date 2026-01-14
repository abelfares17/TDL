open Tds
open Exceptions
open Ast
open Type

type t1 = Ast.AstTds.programme
type t2 = Ast.AstType.programme

(* ========= Expressions ========= *)

let rec analyse_type_expression (e: AstTds.expression) : typ * AstType.expression =
  match e with
  | AstTds.Ident ia ->
      begin
        match info_ast_to_info ia with
        | InfoVar (_, t, _, _) -> (t, AstType.Ident ia)
        | InfoConst (_, _) -> (Int, AstType.Ident ia)
        | InfoFun (n, _, _) -> raise (MauvaiseUtilisationIdentifiant n)
      end

  | AstTds.Booleen b -> (Bool, AstType.Booleen b)
  | AstTds.Entier n  -> (Int, AstType.Entier n)

  | AstTds.AppelFonction (ia_fun, le) ->
      begin
        match info_ast_to_info ia_fun with
        | InfoFun (_, t_ret, ltypes_params) ->
            let l_te_ne = List.map analyse_type_expression le in
            let ltypes_args, nle = List.split l_te_ne in
            if est_compatible_list ltypes_args ltypes_params then
              (t_ret, AstType.AppelFonction (ia_fun, nle))
            else
              raise (TypesParametresInattendus (ltypes_args, ltypes_params))
        | InfoVar (n, _, _, _) | InfoConst (n, _) ->
            raise (MauvaiseUtilisationIdentifiant n)
      end

  | AstTds.Unaire (op, e1) ->
      let (t_e, ne) = analyse_type_expression e1 in
      begin
        match op with
        | AstSyntax.Numerateur ->
            if t_e <> Rat then raise (TypeInattendu (t_e, Rat));
            (Int, AstType.Unaire (AstType.Numerateur, ne))
        | AstSyntax.Denominateur ->
            if t_e <> Rat then raise (TypeInattendu (t_e, Rat));
            (Int, AstType.Unaire (AstType.Denominateur, ne))
      end

  | AstTds.Binaire (op, e1, e2) ->
      let (t1, ne1) = analyse_type_expression e1 in
      let (t2, ne2) = analyse_type_expression e2 in
      begin
        match op with
        | AstSyntax.Fraction ->
            if t1 = Int && t2 = Int then
              (Rat, AstType.Binaire (AstType.Fraction, ne1, ne2))
            else
              raise (TypeBinaireInattendu (op, t1, t2))

        | AstSyntax.Plus ->
            if t1 = Int && t2 = Int then
              (Int, AstType.Binaire (AstType.PlusInt, ne1, ne2))
            else if t1 = Rat && t2 = Rat then
              (Rat, AstType.Binaire (AstType.PlusRat, ne1, ne2))
            else
              raise (TypeBinaireInattendu (op, t1, t2))

        | AstSyntax.Mult ->
            if t1 = Int && t2 = Int then
              (Int, AstType.Binaire (AstType.MultInt, ne1, ne2))
            else if t1 = Rat && t2 = Rat then
              (Rat, AstType.Binaire (AstType.MultRat, ne1, ne2))
            else
              raise (TypeBinaireInattendu (op, t1, t2))

        | AstSyntax.Equ ->
            if t1 = Int && t2 = Int then
              (Bool, AstType.Binaire (AstType.EquInt, ne1, ne2))
            else if t1 = Bool && t2 = Bool then
              (Bool, AstType.Binaire (AstType.EquBool, ne1, ne2))
            else
              raise (TypeBinaireInattendu (op, t1, t2))

        | AstSyntax.Inf ->
            if t1 = Int && t2 = Int then
              (Bool, AstType.Binaire (AstType.Inf, ne1, ne2))
            else
              raise (TypeBinaireInattendu (op, t1, t2))
      end

(* ========= Instructions / Blocs ========= *)

let rec analyse_type_instruction ~(dans_fonction: bool) (i: AstTds.instruction) : AstType.instruction =
  match i with
  | AstTds.Declaration (t_decl, ia, e) ->
      let (t_e, ne) = analyse_type_expression e in
      if est_compatible t_decl t_e then begin
        modifier_type_variable t_decl ia;
        AstType.Declaration (ia, ne)
      end else
        raise (TypeInattendu (t_e, t_decl))

  | AstTds.Affectation (ia, e) ->
      let (t_e, ne) = analyse_type_expression e in
      begin
        match info_ast_to_info ia with
        | InfoVar (_, t_var, _, _) ->
            if est_compatible t_var t_e then
              AstType.Affectation (ia, ne)
            else
              raise (TypeInattendu (t_e, t_var))
        | InfoConst (n, _) | InfoFun (n, _, _) ->
            raise (MauvaiseUtilisationIdentifiant n)
      end

  | AstTds.Affichage e ->
      let (t_e, ne) = analyse_type_expression e in
      begin
        match t_e with
        | Int  -> AstType.AffichageInt ne
        | Rat  -> AstType.AffichageRat ne
        | Bool -> AstType.AffichageBool ne
        | Undefined -> raise (TypeInattendu (Undefined, Int))
      end

  | AstTds.Conditionnelle (c, b1, b2) ->
      let (t_c, nc) = analyse_type_expression c in
      if t_c <> Bool then raise (TypeInattendu (t_c, Bool));
      let nb1 = analyse_type_bloc ~dans_fonction b1 in
      let nb2 = analyse_type_bloc ~dans_fonction b2 in
      AstType.Conditionnelle (nc, nb1, nb2)

  | AstTds.TantQue (c, b) ->
      let (t_c, nc) = analyse_type_expression c in
      if t_c <> Bool then raise (TypeInattendu (t_c, Bool));
      let nb = analyse_type_bloc ~dans_fonction b in
      AstType.TantQue (nc, nb)

  | AstTds.Retour (e, ia_fun) ->
      if not dans_fonction then raise RetourDansMain;
      let (t_e, ne) = analyse_type_expression e in
      begin
        match info_ast_to_info ia_fun with
        | InfoFun (_, t_ret, _) ->
            if est_compatible t_ret t_e then
              AstType.Retour (ne, ia_fun)
            else
              raise (TypeInattendu (t_e, t_ret))
        | _ -> failwith "Retour attaché à un identifiant non-fonction (erreur interne)"
      end

  | AstTds.Empty -> AstType.Empty

and analyse_type_bloc ~(dans_fonction: bool) (b: AstTds.bloc) : AstType.bloc =
  List.map (analyse_type_instruction ~dans_fonction) b

(* ========= Fonctions ========= *)

let analyse_type_fonction (f: AstTds.fonction) : AstType.fonction =
  match f with
  | AstTds.Fonction (_t_ret_syntax, ia_fun, lparams, bloc) ->
      (* lparams : (typ * info_ast) list *)
      let params_types = List.map fst lparams in
      let params_infos = List.map snd lparams in

      (* signature attendue depuis InfoFun *)
      let (_t_ret, ltypes_params_attendus) =
        match info_ast_to_info ia_fun with
        | InfoFun (_, t_ret, ltp) -> (t_ret, ltp)
        | _ -> failwith "InfoFun attendu (erreur interne)"
      in

      (* (optionnel mais propre) : vérifier cohérence signature déclarée vs InfoFun *)
      if not (est_compatible_list params_types ltypes_params_attendus) then
        (* Ici c'est plutôt une incohérence TDS, mais on signale quand même *)
        raise (TypesParametresInattendus (params_types, ltypes_params_attendus));

      (* enregistrer le type de chaque paramètre dans sa InfoVar *)
      List.iter (fun (t_p, ia_p) -> modifier_type_variable t_p ia_p) lparams;

      (* typer le corps *)
      let nbloc = analyse_type_bloc ~dans_fonction:true bloc in

      (* AstType.Fonction attend : info_fun * info_ast list * bloc *)
      AstType.Fonction (ia_fun, params_infos, nbloc)

(* ========= Programme ========= *)

let analyser (AstTds.Programme (lf, bloc_main) : t1) : t2 =
  let nlf = List.map analyse_type_fonction lf in
  let nbloc_main = analyse_type_bloc ~dans_fonction:false bloc_main in
  AstType.Programme (nlf, nbloc_main)