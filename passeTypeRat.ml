open Tds
open Exceptions
open Ast
open Type

type t1 = Ast.AstTds.programme
type t2 = Ast.AstType.programme

(* ========= Affectables ========= *)

let rec analyse_type_affectable (a: AstTds.affectable) : typ * AstType.affectable =
  match a with
  | AstTds.Ident ia ->
      begin
        match info_ast_to_info ia with
        | InfoVar (_, t, _, _, _) -> (t, AstTds.Ident ia)
        | InfoConst (_, _) -> (Int, AstTds.Ident ia)
        | InfoFun (n, _, _) -> raise (MauvaiseUtilisationIdentifiant n)
        | InfoEnum (n, _) -> raise (MauvaiseUtilisationIdentifiant n)
        | InfoValeurEnum (n, _, _) -> raise (MauvaiseUtilisationIdentifiant n)
      end
  | AstTds.Deref aff ->
      let (t_aff, naff) = analyse_type_affectable aff in
      begin
        match t_aff with
        | Pointeur t -> (t, AstTds.Deref naff)  (* Déréférencement d'un pointeur retourne le type pointé *)
        | _ -> raise (TypeInattendu (t_aff, Pointeur Undefined))
      end

(* ========= Expressions ========= *)

let rec analyse_type_expression (e: AstTds.expression) : typ * AstType.expression =
  match e with
  | AstTds.Affectable a ->
      let (t_a, na) = analyse_type_affectable a in
      (t_a, AstType.Affectable na)

  | AstTds.Booleen b -> (Bool, AstType.Booleen b)
  | AstTds.Entier n  -> (Int, AstType.Entier n)

  | AstTds.IdentEnum ia ->
      begin
        match info_ast_to_info ia with
        | InfoValeurEnum (_, nom_type, _) -> (Enum nom_type, AstType.IdentEnum ia)
        | _ -> failwith "IdentEnum doit être associé à InfoValeurEnum"
      end

  | AstTds.Null ->
      (* null est compatible avec tout pointeur, on utilise Pointeur Undefined *)
      (Pointeur Undefined, AstType.Null)

  | AstTds.New t ->
      (* new TYPE retourne un pointeur sur TYPE *)
      (Pointeur t, AstType.New t)

  | AstTds.Adresse ia ->
      begin
        match info_ast_to_info ia with
        | InfoVar (_, t, _, _, _) -> (Pointeur t, AstType.Adresse ia)
        | _ -> failwith "Adresse doit être associé à une variable"
      end

  | AstTds.AppelFonction (ia_fun, args) ->
      begin
        match info_ast_to_info ia_fun with
        | InfoFun (_, t_ret, ltypes_params) ->
            (* Analyser les arguments et extraire infos *)
            let args_analyzed = List.map analyse_type_argument args in
            let args_ref_flags = List.map (fun (ref_flag, _, _) -> ref_flag) args_analyzed in
            let args_types = List.map (fun (_, t, _) -> t) args_analyzed in
            let nargs = List.map (fun (_, _, arg) -> arg) args_analyzed in

            (* Extraire les flags ref et types des paramètres formels *)
            let params_ref_flags = List.map fst ltypes_params in
            let params_types = List.map snd ltypes_params in

            (* VALIDATION 0 : Vérifier d'abord le nombre de paramètres *)
            if List.length args_types <> List.length params_types then
              raise (TypesParametresInattendus (args_types, params_types));

            (* VALIDATION 1 : Vérifier cohérence des flags ref *)
            if args_ref_flags <> params_ref_flags then
              raise (IncoherenceRefParametres (args_ref_flags, params_ref_flags));

            (* VALIDATION 2 : Vérifier compatibilité des types *)
            if est_compatible_list args_types params_types then
              (t_ret, AstType.AppelFonction (ia_fun, nargs))
            else
              raise (TypesParametresInattendus (args_types, params_types))
        | InfoVar (n, _, _, _, _) | InfoConst (n, _) | InfoEnum (n, _) | InfoValeurEnum (n, _, _) ->
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
            else if est_compatible t1 t2 then
              (* Vérifier si c'est un enum ou un pointeur *)
              begin
                match t1 with
                | Enum _ -> (Bool, AstType.Binaire (AstType.EquEnum, ne1, ne2))
                | Pointeur _ -> (Bool, AstType.Binaire (AstType.EquInt, ne1, ne2))  (* Pointeurs comparés comme entiers *)
                | _ -> raise (TypeBinaireInattendu (op, t1, t2))
              end
            else
              raise (TypeBinaireInattendu (op, t1, t2))

        | AstSyntax.Inf ->
            if t1 = Int && t2 = Int then
              (Bool, AstType.Binaire (AstType.Inf, ne1, ne2))
            else
              raise (TypeBinaireInattendu (op, t1, t2))
      end

(* ========= Arguments ========= *)

(* Analyse un argument d'appel de fonction *)
(* Retourne (is_ref, type, argument_typé) *)
and analyse_type_argument arg =
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
          failwith "Impossible : PasseTds devrait avoir vérifié que ref contient un affectable"

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

  | AstTds.Affectation (aff, e) ->
      (* Analyse de l'affectable pour obtenir son type *)
      let (t_aff, naff) = analyse_type_affectable aff in
      (* Analyse de l'expression *)
      let (t_e, ne) = analyse_type_expression e in
      (* Vérification de la compatibilité des types *)
      if est_compatible t_aff t_e then
        AstType.Affectation (naff, ne)
      else
        raise (TypeInattendu (t_e, t_aff))

  | AstTds.Affichage e ->
      let (t_e, ne) = analyse_type_expression e in
      begin
        match t_e with
        | Int  -> AstType.AffichageInt ne
        | Rat  -> AstType.AffichageRat ne
        | Bool -> AstType.AffichageBool ne
        | Enum _ -> AstType.AffichageInt ne  (* Les enums sont représentés comme des entiers *)
        | Pointeur _ -> AstType.AffichageInt ne  (* Les pointeurs sont représentés comme des entiers (adresses) *)
        | Void -> raise (TypeInattendu (Void, Int))
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

  | AstTds.Retour (eo, ia_fun) ->
      if not dans_fonction then raise RetourDansMain;
      begin
        match info_ast_to_info ia_fun with
        | InfoFun (_, t_ret, _) ->
            begin
              match eo with
              | Some e ->
                  (* Return avec expression : vérifier que le type correspond au type de retour de la fonction *)
                  let (t_e, ne) = analyse_type_expression e in
                  if est_compatible t_ret t_e then
                    AstType.Retour (Some ne, ia_fun)
                  else
                    raise (TypeInattendu (t_e, t_ret))
              | None ->
                  (* Return sans expression : vérifier que la fonction est void *)
                  if t_ret = Void then
                    AstType.Retour (None, ia_fun)
                  else
                    raise (TypeInattendu (Void, t_ret))
            end
        | _ -> failwith "Retour attaché à un identifiant non-fonction (erreur interne)"
      end

  | AstTds.AppelProc (ia_fun, args) ->
      begin
        match info_ast_to_info ia_fun with
        | InfoFun (_, t_ret, ltypes_params) ->
            (* Vérifier que c'est bien une procédure (type retour Void) *)
            if t_ret <> Void then
              raise (TypeInattendu (t_ret, Void));

            (* Analyser les arguments et extraire infos *)
            let args_analyzed = List.map analyse_type_argument args in
            let args_ref_flags = List.map (fun (ref_flag, _, _) -> ref_flag) args_analyzed in
            let args_types = List.map (fun (_, t, _) -> t) args_analyzed in
            let nargs = List.map (fun (_, _, arg) -> arg) args_analyzed in

            (* Extraire les flags ref et types des paramètres formels *)
            let params_ref_flags = List.map fst ltypes_params in
            let params_types = List.map snd ltypes_params in

            (* VALIDATION 0 : Vérifier d'abord le nombre de paramètres *)
            if List.length args_types <> List.length params_types then
              raise (TypesParametresInattendus (args_types, params_types));

            (* VALIDATION 1 : Vérifier cohérence des flags ref *)
            if args_ref_flags <> params_ref_flags then
              raise (IncoherenceRefParametres (args_ref_flags, params_ref_flags));

            (* VALIDATION 2 : Vérifier compatibilité des types *)
            if est_compatible_list args_types params_types then
              AstType.AppelProc (ia_fun, nargs)
            else
              raise (TypesParametresInattendus (args_types, params_types))
        | _ -> failwith "AppelProc attaché à un identifiant non-fonction (erreur interne)"
      end

  | AstTds.Empty -> AstType.Empty

and analyse_type_bloc ~(dans_fonction: bool) (b: AstTds.bloc) : AstType.bloc =
  List.map (analyse_type_instruction ~dans_fonction) b

(* ========= Fonctions ========= *)

let analyse_type_fonction (f: AstTds.fonction) : AstType.fonction =
  match f with
  | AstTds.Fonction (_t_ret_syntax, ia_fun, lparams, bloc) ->
      (* lparams : (typ * info_ast) list *)
      let params_types = List.map (fun (_, t, _) -> t) lparams in
      let params_infos = List.map (fun (_, _, ia) -> ia) lparams in

      (* signature attendue depuis InfoFun *)
      let (_t_ret, ltypes_params_attendus) =
        match info_ast_to_info ia_fun with
        | InfoFun (_, t_ret, ltp) -> (t_ret, ltp)
        | _ -> failwith "InfoFun attendu (erreur interne)"
      in

      (* (optionnel mais propre) : vérifier cohérence signature déclarée vs InfoFun *)
      if not (est_compatible_list params_types (List.map snd ltypes_params_attendus)) then
        (* Ici c'est plutôt une incohérence TDS, mais on signale quand même *)
        raise (TypesParametresInattendus (params_types, (List.map snd ltypes_params_attendus)));

      (* enregistrer le type de chaque paramètre dans sa InfoVar *)
      List.iter (fun (_, t_p, ia_p) -> modifier_type_variable t_p ia_p) lparams;

      (* typer le corps *)
      let nbloc = analyse_type_bloc ~dans_fonction:true bloc in

      (* AstType.Fonction attend : info_fun * info_ast list * bloc *)
      AstType.Fonction (ia_fun, params_infos, nbloc)

(* ========= Programme ========= *)

let analyser (AstTds.Programme (lf, bloc_main) : t1) : t2 =
  let nlf = List.map analyse_type_fonction lf in
  let nbloc_main = analyse_type_bloc ~dans_fonction:false bloc_main in
  AstType.Programme (nlf, nbloc_main)