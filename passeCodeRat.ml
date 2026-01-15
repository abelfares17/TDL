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
  let params = types_parametres_fonction ia in
  List.fold_left (fun acc (is_ref, t) ->
    if is_ref then acc + 1  (* Un paramètre ref prend 1 mot (adresse) *)
    else acc + getTaille t
  ) 0 params

let load_ident ia =
  match info_ast_to_info ia with
  | InfoVar (_, t, dep, reg, is_ref) ->
      if is_ref then
        (* Paramètre ref : charger l'adresse puis déréférencer *)
        Tam.load 1 dep reg ^ Tam.loadi (getTaille t)
      else
        Tam.load (getTaille t) dep reg
  | InfoConst (_, v) ->
      Tam.loadl_int v
  | InfoValeurEnum (_, _, idx) ->
      Tam.loadl_int idx
  | InfoFun _ ->
      failwith "load_ident: identifiant de fonction utilisé comme expression"
  | InfoEnum _ ->
      failwith "load_ident: type enum utilisé comme expression"

let store_var ia =
  match info_ast_to_info ia with
  | InfoVar (_, t, dep, reg, is_ref) ->
      if is_ref then
        (* Paramètre ref : charger l'adresse puis stocker indirectement *)
        Tam.load 1 dep reg ^ Tam.storei (getTaille t)
      else
        Tam.store (getTaille t) dep reg
  | _ ->
      failwith "store_var: InfoVar attendu"
  
let rec get_type_affectable (a : AstPlacement.affectable) : typ =
  match a with
  | AstTds.Ident ia ->
      begin
        match info_ast_to_info ia with
        | InfoVar (_, t, _, _, _) -> t
        | InfoConst _ -> Int
        | InfoValeurEnum _ -> Int
        | _ -> failwith "get_type_affectable: Identifiant inattendu"
      end
  | AstTds.Deref aff ->
      (* On récupère le type de l'affectable déréférencé (qui doit être un pointeur) *)
      let t = get_type_affectable aff in
      begin
        match t with
        | Pointeur t_pointe -> t_pointe
        | _ -> failwith "get_type_affectable: Déréférencement d'un non-pointeur"
      end

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
(* Génération code affectables                             *)
(* ------------------------------------------------------- *)

let rec analyse_code_affectable_lecture (a : AstPlacement.affectable) : string =
  match a with
  | AstTds.Ident ia ->
      load_ident ia
  | AstTds.Deref aff ->
      (* Générer le code pour obtenir l'adresse (pointeur) *)
      let c_aff = analyse_code_affectable_lecture aff in
      
      (* Calculer la taille du type pointé pour savoir combien de mots lire *)
      let t = get_type_affectable a in (* a est le Deref ici *)
      let taille = getTaille t in
      
      (* Puis déréférencer avec la bonne taille *)
      c_aff ^ Tam.loadi taille

(* ------------------------------------------------------- *)
(* Génération code expressions                             *)
(* ------------------------------------------------------- *)

let rec analyse_code_expression (e : AstPlacement.expression) : string =
  match e with
  | AstType.Entier n ->
      Tam.loadl_int n

  | AstType.Booleen b ->
      Tam.loadl_int (if b then 1 else 0)

  | AstType.Affectable a ->
      analyse_code_affectable_lecture a

  | AstType.IdentEnum ia ->
      begin
        match info_ast_to_info ia with
        | InfoValeurEnum (_, _, idx) -> Tam.loadl_int idx
        | _ -> failwith "IdentEnum doit être associé à InfoValeurEnum"
      end

  | AstType.Null ->
      (* Représenter null comme -1 ou 0 *)
      Tam.loadl_int 0

  | AstType.New t ->
      (* Allocation dynamique: empiler la taille puis appeler MAlloc *)
      Tam.loadl_int (getTaille t) ^ Tam.subr "MAlloc"

  | AstType.Adresse ia ->
      begin
        match info_ast_to_info ia with
        | InfoVar (_, _, dep, reg, _) -> Tam.loada dep reg
        | _ -> failwith "Adresse doit être associé à une variable"
      end

  | AstType.AppelFonction (ia_fun, args) ->
      (* Récupérer les informations sur les paramètres de la fonction *)
      let params_info = types_parametres_fonction ia_fun in
      (* Générer le code pour chaque argument *)
      let code_args = String.concat "" (
        List.map2 (fun (is_ref_param, _) arg ->
          match arg with
          | AstType.ArgNormal e ->
              (* Type checker garantit que paramètre n'est pas ref *)
              if is_ref_param then failwith "IMPOSSIBLE: type checker should have caught this";
              analyse_code_expression e
          | AstType.ArgRef aff ->
              (* Type checker garantit que paramètre est ref *)
              if not is_ref_param then failwith "IMPOSSIBLE: type checker should have caught this";
              (* Analyser l'affectable pour obtenir son adresse *)
              match aff with
              | AstTds.Ident ia ->
                  begin
                    match info_ast_to_info ia with
                    | InfoVar (_, _, dep, reg, is_ref_var) ->
                        if is_ref_var then
                          (* Variable est déjà un param ref : charger valeur (adresse) *)
                          Tam.load 1 dep reg
                        else
                          (* Variable normale : charger son adresse *)
                          Tam.loada dep reg
                    | _ -> failwith "Impossible : doit être une variable"
                  end
              | AstTds.Deref inner_aff ->
                  (* Déréférencement : passer le pointeur lui-même *)
                  analyse_code_affectable_lecture inner_aff
        ) params_info args
      ) in
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

        | AstType.EquEnum ->
            c1 ^ c2 ^ Tam.subr "IEq"

        | AstType.Inf ->
            c1 ^ c2 ^ Tam.subr "ILss"
      end

(* ------------------------------------------------------- *)
(* Génération code instructions / blocs                    *)
(* ------------------------------------------------------- *)

let analyse_code_affectable_ecriture (a : AstPlacement.affectable) (code_valeur : string) : string =
  match a with
  | AstTds.Ident ia ->
      (* code_valeur empile la valeur, store_var sait stocker (direct ou ref) *)
      code_valeur ^ store_var ia
  | AstTds.Deref aff ->
      (* 1. Obtenir l'adresse du pointeur *)
      let c_aff = analyse_code_affectable_lecture aff in
      
      (* 2. Calculer la taille pour le STOREI *)
      let t = get_type_affectable a in
      let taille = getTaille t in
      
      (* 3. Empiler la valeur puis l'adresse, puis STOREI *)
      (* Attention : STOREI attend (valeur...adresse) sur la pile ? *)
      (* Vérifions TAM : STOREI (n) prend l'adresse au sommet et n mots sous l'adresse. *)
      (* Votre ordre initial : code_valeur ^ c_aff ^ storei *)
      (* Pile : [ ... | valeur (n mots) | adresse (1 mot) ] -> STOREI consomme tout. C'est bon. *)
      
      code_valeur ^ c_aff ^ Tam.storei taille

let rec analyse_code_instruction (i : AstPlacement.instruction) : string =
  match i with
  | AstPlacement.Declaration (ia, e) ->
      analyse_code_expression e ^ store_var ia

  | AstPlacement.Affectation (aff, e) ->
      let code_valeur = analyse_code_expression e in
      analyse_code_affectable_ecriture aff code_valeur

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

  | AstPlacement.Retour (eo, taille_ret, taille_params) ->
      begin
        match eo with
        | Some e ->
            (* Return avec expression *)
            analyse_code_expression e ^ Tam.return taille_ret taille_params
        | None ->
            (* Return sans expression (procédure) *)
            Tam.return taille_ret taille_params
      end

  | AstPlacement.AppelProc (ia_fun, args) ->
      (* Appel de procédure : évaluer les arguments et appeler *)
      (* Récupérer les informations sur les paramètres de la fonction *)
      let params_info = types_parametres_fonction ia_fun in
      (* Générer le code pour chaque argument *)
      let code_args = String.concat "" (
        List.map2 (fun (is_ref_param, _) arg ->
          match arg with
          | AstType.ArgNormal e ->
              (* Type checker garantit que paramètre n'est pas ref *)
              if is_ref_param then failwith "IMPOSSIBLE: type checker should have caught this";
              analyse_code_expression e
          | AstType.ArgRef aff ->
              (* Type checker garantit que paramètre est ref *)
              if not is_ref_param then failwith "IMPOSSIBLE: type checker should have caught this";
              (* Analyser l'affectable pour obtenir son adresse *)
              match aff with
              | AstTds.Ident ia ->
                  begin
                    match info_ast_to_info ia with
                    | InfoVar (_, _, dep, reg, is_ref_var) ->
                        if is_ref_var then
                          (* Variable est déjà un param ref : charger valeur (adresse) *)
                          Tam.load 1 dep reg
                        else
                          (* Variable normale : charger son adresse *)
                          Tam.loada dep reg
                    | _ -> failwith "Impossible : doit être une variable"
                  end
              | AstTds.Deref inner_aff ->
                  (* Déréférencement : passer le pointeur lui-même *)
                  analyse_code_affectable_lecture inner_aff
        ) params_info args
      ) in
      code_args ^ Tam.call "SB" (nom_fonction ia_fun)

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
     - si pas de retour garanti :
       * pour une procédure (void), on ajoute RETURN (0) taille_params
       * pour une fonction, on HALT pour éviter le fall-through *)
  if bloc_retour_garanti li then
    code_corps
  else
    (* Vérifier si c'est une procédure *)
    match info_ast_to_info ia_fun with
    | InfoFun (_, t_ret, _) ->
        if t_ret = Void then
          (* Procédure : retour implicite *)
          code_corps ^ Tam.return 0 (taille_parametres_fonction ia_fun)
        else
          (* Fonction : HALT pour signaler erreur *)
          code_corps ^ Tam.halt
    | _ -> failwith "analyse_code_fonction: InfoFun attendu"

let analyser (AstPlacement.Programme (fonctions, bloc_main) : t1) : t2 =
  let code_fcts = String.concat "" (List.map analyse_code_fonction fonctions) in
  let code_main =
    Tam.label "main"
    ^ analyse_code_bloc ~pop_end:false bloc_main
    ^ Tam.halt
  in
  Code.getEntete () ^ code_fcts ^ code_main