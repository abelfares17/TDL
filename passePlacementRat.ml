open Tds
open Type
open Ast

  type t1 = Ast.AstType.programme
  type t2 = Ast.AstPlacement.programme

  (*
    Convention de placement :

    - Programme principal :
        base = "SB"
        dep  = 0 au début
        Variables placées à partir de 0, en augmentant dep.

    - Fonctions :
        base = "LB"

        Enregistrement d'activation (EA) : 3 mots
        0[LB] = lien dynamique (DL)
        1[LB] = lien statique  (SL)
        2[LB] = adresse de retour (RA)
        => les variables locales commencent à 3[LB]

        Paramètres :
          - en négatif sur LB
          - si taille_params = somme des tailles des paramètres
            alors on place le 1er param à -taille_params[LB]
            et le dernier param finit à -1[LB]

        Variables locales :
          - en positif sur LB, à partir de 3

        Retour :
          Retour (exp, taille_retour, taille_params)
  *)

  let taille_enregistrement_activation = 3

  (* ========================= *)
  (* Placement d'une instruction *)
  (* ========================= *)

  (*
    analyse_placement_instruction :
      base          : "SB" ou "LB"
      dep           : déplacement courant (prochaine case libre)
      taille_retour : taille du résultat (0 pour le main)
      taille_params : taille totale des paramètres (0 pour le main)

    Renvoie :
      - instruction placée
      - nouveau dep après l'instruction
      - pic_local : mémoire supplémentaire occupée par cette instruction
                    par rapport au dep d'entrée
  *)
  let rec analyse_placement_instruction base dep taille_retour taille_params i =
    match i with
    | AstType.Declaration (ia, e) ->
        begin
          match info_ast_to_info ia with
          | InfoVar (_, t, _, _, _) ->
              let taille = getTaille t in
              modifier_adresse_variable dep base ia;
              let dep_apres = dep + taille in
              (AstPlacement.Declaration (ia, e), dep_apres, taille)
          | _ ->
              failwith "Declaration non associée à un InfoVar (PassePlacementRat)"
        end

    | AstType.Affectation (ia, e) ->
        (AstPlacement.Affectation (ia, e), dep, 0)

    | AstType.AffichageInt e ->
        (AstPlacement.AffichageInt e, dep, 0)

    | AstType.AffichageRat e ->
        (AstPlacement.AffichageRat e, dep, 0)

    | AstType.AffichageBool e ->
        (AstPlacement.AffichageBool e, dep, 0)

    | AstType.Conditionnelle (c, bloc_then, bloc_else) ->
        let nbloc_then = analyse_placement_bloc base dep taille_retour taille_params bloc_then in
        let nbloc_else = analyse_placement_bloc base dep taille_retour taille_params bloc_else in
        let _, taille_then = nbloc_then in
        let _, taille_else = nbloc_else in
        let pic_local = max taille_then taille_else in
        (AstPlacement.Conditionnelle (c, nbloc_then, nbloc_else), dep, pic_local)

    | AstType.TantQue (c, bloc) ->
        let nbloc = analyse_placement_bloc base dep taille_retour taille_params bloc in
        let _, taille_bloc = nbloc in
        (AstPlacement.TantQue (c, nbloc), dep, taille_bloc)

    | AstType.Retour (e, _ia_fun) ->
        (AstPlacement.Retour (e, taille_retour, taille_params), dep, 0)

    | AstType.AppelProc (ia_fun, args) ->
        (AstPlacement.AppelProc (ia_fun, args), dep, 0)

    | AstType.Empty ->
        (AstPlacement.Empty, dep, 0)

  (* ========================= *)
  (* Placement d'un bloc       *)
  (* ========================= *)

  (*
    analyse_placement_bloc :
      base, dep0, taille_retour, taille_params
      li : AstType.bloc = liste d'instructions

    Renvoie :
      AstPlacement.bloc = (liste_instructions_placees, taille_bloc)
      où taille_bloc = pic de mémoire supplémentaire consommée dans ce bloc
      par rapport à dep0.
  *)
  and analyse_placement_bloc base dep0 taille_retour taille_params (li : AstType.bloc)
      : AstPlacement.bloc =
    let rec aux dep cur_max = function
      | [] -> ([], cur_max, dep)
      | i :: q ->
          let (ni, dep_apres, pic_local) =
            analyse_placement_instruction base dep taille_retour taille_params i
          in
          (* pic absolu vs début du bloc *)
          let pic_absolu = (dep - dep0) + pic_local in
          let nouveau_max = max cur_max pic_absolu in
          let (nq, max_q, dep_final) = aux dep_apres nouveau_max q in
          (ni :: nq, max_q, dep_final)
    in
    let (nli, taille_bloc, _dep_final) = aux dep0 0 li in
    (nli, taille_bloc)

  (* ========================= *)
  (* Placement d'une fonction  *)
  (* ========================= *)

  let analyse_placement_fonction
      (AstType.Fonction (ia_fun, lparams, bloc) : AstType.fonction)
    : AstPlacement.fonction =

    (* Récupérer type retour + types params depuis InfoFun *)
    let (t_retour, ltypes_params) =
      match info_ast_to_info ia_fun with
      | InfoFun (_, t_ret, ltp) -> (t_ret, ltp)
      | _ -> failwith "InfoFun attendu pour une fonction (PassePlacementRat)"
    in
    let taille_retour = getTaille t_retour in

    (* Taille totale des paramètres *)
    let taille_params =
      List.fold_left (fun acc (is_ref, t) -> if is_ref then acc + 1 else acc + getTaille t) 0 ltypes_params
    in

    (* 1) Paramètres en négatif : de -taille_params à -1 *)
    let rec place_params dep acc = function
      | [] -> List.rev acc
      | ia_param :: q ->
          begin
            match info_ast_to_info ia_param with
            | InfoVar (_, t_param, _, _, is_ref) ->
                (* Un paramètre ref prend 1 mot (adresse), sinon la taille du type *)
                let taille = if is_ref then 1 else getTaille t_param in
                modifier_adresse_variable dep "LB" ia_param;
                place_params (dep + taille) (ia_param :: acc) q
            | _ ->
                failwith "Paramètre non InfoVar (PassePlacementRat)"
          end
    in
    let lparams_placed = place_params (-taille_params) [] lparams in

    (* 2) Variables locales : à partir de 3[LB] (EA = 3 mots) *)
    let nbloc =
      analyse_placement_bloc "LB" taille_enregistrement_activation
        taille_retour taille_params bloc
    in

    AstPlacement.Fonction (ia_fun, lparams_placed, nbloc)

  (* ========================= *)
  (* Programme complet         *)
  (* ========================= *)

  let analyser (AstType.Programme (lf, bloc_principal) : t1) : t2 =
    let nlf = List.map analyse_placement_fonction lf in
    let nbloc_principal = analyse_placement_bloc "SB" 0 0 0 bloc_principal in
    AstPlacement.Programme (nlf, nbloc_principal)
