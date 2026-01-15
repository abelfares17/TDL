(* Module de la passe de gestion des identifiants *)
(* doit être conforme à l'interface Passe *)
open Tds
open Exceptions
open Ast

type t1 = Ast.AstSyntax.programme
type t2 = Ast.AstTds.programme

(* analyse_tds_affectable : tds -> AstSyntax.affectable -> AstTds.affectable *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre a : l'affectable à analyser *)
(* Vérifie la bonne utilisation des identifiants et transforme l'affectable
en un affectable de type AstTds.affectable *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_tds_affectable tds a =
  match a with
  | AstSyntax.Ident s ->
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
      (* Analyse récursive du sous-affectable *)
      let naff = analyse_tds_affectable tds aff in
      AstTds.Deref naff

(* analyse_tds_expression : tds -> AstSyntax.expression -> AstTds.expression *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre e : l'expression à analyser *)
(* Analyse un argument d'appel de fonction *)
(* Vérifie que les arguments ref sont des affectables *)
let rec analyse_tds_argument tds arg =
  match arg with
  | AstSyntax.ArgNormal e ->
      let ne = analyse_tds_expression tds e in
      AstTds.ArgNormal ne
  | AstSyntax.ArgRef e ->
      (* Vérifier que e est un affectable *)
      match e with
      | AstSyntax.Affectable aff ->
          let naff = analyse_tds_affectable tds aff in
          AstTds.ArgRef (AstTds.Affectable naff)
      | _ ->
          raise (MauvaiseUtilisationIdentifiant "ref")

(* Vérifie la bonne utilisation des identifiants et tranforme l'expression
en une expression de type AstTds.expression *)
(* Erreur si mauvaise utilisation des identifiants *)
and analyse_tds_expression tds e =
  match e with
  | AstSyntax.Affectable a ->
      (* Analyse de l'affectable *)
      let na = analyse_tds_affectable tds a in
      AstTds.Affectable na
  
    |AstSyntax.Booleen b ->
      AstTds.Booleen b
    
    |AstSyntax.Entier e ->
      AstTds.Entier e
    
    |AstSyntax.Unaire (u,e) ->
      let ne = analyse_tds_expression tds e in 
      AstTds.Unaire (u,ne)

    |AstSyntax.Binaire (b,eg,ed)->
      let neg=analyse_tds_expression tds eg in
      let ned=analyse_tds_expression tds ed in
      AstTds.Binaire (b,neg,ned)

    |AstSyntax.IdentEnum n ->
      begin
        match chercherGlobalement tds n with
        | None -> raise(IdentifiantNonDeclare n)
        | Some info ->
            begin
              match info_ast_to_info info with
              | InfoValeurEnum _ -> AstTds.IdentEnum info
              | _ -> raise(MauvaiseUtilisationIdentifiant n)
            end
      end

    |AstSyntax.AppelFonction (n,args) ->
      begin
        match chercherGlobalement tds n with
        |None->raise(IdentifiantNonDeclare n)
        |Some info ->
          begin
            match info_ast_to_info info with
            |InfoFun _ ->
                  let nargs = List.map (analyse_tds_argument tds) args in
                  AstTds.AppelFonction (info, nargs)
            | _ -> raise(MauvaiseUtilisationIdentifiant n)
          end
      end

    |AstSyntax.Null ->
      AstTds.Null

    |AstSyntax.New t ->
      AstTds.New t

    |AstSyntax.Adresse n ->
      begin
        match chercherGlobalement tds n with
        | None -> raise (IdentifiantNonDeclare n)
        | Some info ->
            begin
              match info_ast_to_info info with
              | InfoVar _ -> AstTds.Adresse info
              | _ -> raise (MauvaiseUtilisationIdentifiant n)
            end
      end





(* analyse_tds_instruction : tds -> info_ast option -> AstSyntax.instruction -> AstTds.instruction *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre oia : None si l'instruction i est dans le bloc principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est l'instruction i sinon *)
(* Paramètre i : l'instruction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme l'instruction
en une instruction de type AstTds.instruction *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_tds_instruction tds oia i =
  match i with
  | AstSyntax.Declaration (t, n, e) ->
      begin
        match chercherLocalement tds n with
        | None ->
            (* L'identifiant n'est pas trouvé dans la tds locale,
            il n'a donc pas été déclaré dans le bloc courant *)
            (* Vérification de la bonne utilisation des identifiants dans l'expression *)
            (* et obtention de l'expression transformée *)
            let ne = analyse_tds_expression tds e in
            (* Création de l'information associée à l'identfiant *)
            let info = InfoVar (n,Undefined, 0, "", false) in
            (* Création du pointeur sur l'information *)
            let ia = info_to_info_ast info in
            (* Ajout de l'information (pointeur) dans la tds *)
            ajouter tds n ia;
            (* Renvoie de la nouvelle déclaration où le nom a été remplacé par l'information
            et l'expression remplacée par l'expression issue de l'analyse *)
            AstTds.Declaration (t, ia, ne)
        | Some _ ->
            (* L'identifiant est trouvé dans la tds locale,
            il a donc déjà été déclaré dans le bloc courant *)
            raise (DoubleDeclaration n)
      end
  | AstSyntax.Affectation (aff,e) ->
      (* Analyse de l'affectable *)
      let naff = analyse_tds_affectable tds aff in
      (* Vérification que l'affectable est bien une variable (pas une constante) *)
      (* Cette vérification se fait uniquement pour les identifiants simples *)
      begin
        match aff with
        | AstSyntax.Ident n ->
            begin
              match chercherGlobalement tds n with
              | None -> raise (IdentifiantNonDeclare n)
              | Some info ->
                  begin
                    match info_ast_to_info info with
                    | InfoVar _ -> ()  (* OK, c'est une variable *)
                    | _ -> raise (MauvaiseUtilisationIdentifiant n)  (* Constante ou fonction *)
                  end
            end
        | AstSyntax.Deref _ -> ()  (* Pour les déréférencements, la vérification sera faite au typage *)
      end;
      (* Vérification de la bonne utilisation des identifiants dans l'expression *)
      (* et obtention de l'expression transformée *)
      let ne = analyse_tds_expression tds e in
      (* Renvoie de la nouvelle affectation *)
      AstTds.Affectation (naff, ne)
  | AstSyntax.Constante (n,v) ->
      begin
        match chercherLocalement tds n with
        | None ->
          (* L'identifiant n'est pas trouvé dans la tds locale,
             il n'a donc pas été déclaré dans le bloc courant *)
          (* Ajout dans la tds de la constante *)
          ajouter tds n (info_to_info_ast (InfoConst (n,v)));
          (* Suppression du noeud de déclaration des constantes devenu inutile *)
          AstTds.Empty
        | Some _ ->
          (* L'identifiant est trouvé dans la tds locale,
          il a donc déjà été déclaré dans le bloc courant *)
          raise (DoubleDeclaration n)
      end
  | AstSyntax.Affichage e ->
      (* Vérification de la bonne utilisation des identifiants dans l'expression *)
      (* et obtention de l'expression transformée *)
      let ne = analyse_tds_expression tds e in
      (* Renvoie du nouvel affichage où l'expression remplacée par l'expression issue de l'analyse *)
      AstTds.Affichage (ne)
  | AstSyntax.Conditionnelle (c,t,e) ->
      (* Analyse de la condition *)
      let nc = analyse_tds_expression tds c in
      (* Analyse du bloc then *)
      let tast = analyse_tds_bloc tds oia t in
      (* Analyse du bloc else *)
      let east = analyse_tds_bloc tds oia e in
      (* Renvoie la nouvelle structure de la conditionnelle *)
      AstTds.Conditionnelle (nc, tast, east)
  | AstSyntax.TantQue (c,b) ->
      (* Analyse de la condition *)
      let nc = analyse_tds_expression tds c in
      (* Analyse du bloc *)
      let bast = analyse_tds_bloc tds oia b in
      (* Renvoie la nouvelle structure de la boucle *)
      AstTds.TantQue (nc, bast)
  | AstSyntax.Retour (eo) ->
      begin
      (* On récupère l'information associée à la fonction à laquelle le return est associée *)
      match oia with
        (* Il n'y a pas d'information -> l'instruction est dans le bloc principal : erreur *)
      | None -> raise RetourDansMain
        (* Il y a une information -> l'instruction est dans une fonction *)
      | Some ia ->
        (* Analyse de l'expression optionnelle *)
        let neo = Option.map (analyse_tds_expression tds) eo in
        AstTds.Retour (neo,ia)
      end
  | AstSyntax.AppelProc (n,args) ->
      begin
        match chercherGlobalement tds n with
        |None->raise(IdentifiantNonDeclare n)
        |Some info ->
          begin
            match info_ast_to_info info with
            |InfoFun _ ->
                  let nargs = List.map (analyse_tds_argument tds) args in
                  AstTds.AppelProc (info, nargs)
            | _ -> raise(MauvaiseUtilisationIdentifiant n)
          end
      end


(* analyse_tds_bloc : tds -> info_ast option -> AstSyntax.bloc -> AstTds.bloc *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre oia : None si le bloc li est dans le programme principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est le bloc li sinon *)
(* Paramètre li : liste d'instructions à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le bloc en un bloc de type AstTds.bloc *)
(* Erreur si mauvaise utilisation des identifiants *)
and analyse_tds_bloc tds oia li =
  (* Entrée dans un nouveau bloc, donc création d'une nouvelle tds locale
  pointant sur la table du bloc parent *)
  let tdsbloc = creerTDSFille tds in
  (* Analyse des instructions du bloc avec la tds du nouveau bloc.
     Cette tds est modifiée par effet de bord *)
   let nli = List.map (analyse_tds_instruction tdsbloc oia) li in
   (* afficher_locale tdsbloc ; *) (* décommenter pour afficher la table locale *)
   nli


(* analyse_tds_enum : tds -> AstSyntax.enum_decl -> unit *)
(* Analyse une déclaration d'enum et l'ajoute dans la TDS *)
(* Vérifie qu'il n'y a pas de conflit de noms et ajoute les valeurs enum *)
let analyse_tds_enum tds (nom_type, valeurs) =
  (* Vérifier que le nom du type n'existe pas déjà *)
  begin
    match chercherLocalement tds nom_type with
    | Some _ -> raise (DoubleDeclaration nom_type)
    | None ->
        (* Ajouter l'InfoEnum dans la TDS *)
        let info_enum = InfoEnum (nom_type, valeurs) in
        let ia_enum = info_to_info_ast info_enum in
        ajouter tds nom_type ia_enum;

        (* Ajouter chaque valeur de l'enum dans la TDS avec son index *)
        List.iteri (fun idx nom_val ->
          match chercherLocalement tds nom_val with
          | Some _ -> raise (DoubleDeclaration nom_val)
          | None ->
              let info_val = InfoValeurEnum (nom_val, nom_type, idx) in
              let ia_val = info_to_info_ast info_val in
              ajouter tds nom_val ia_val
        ) valeurs
  end

(* analyse_tds_fonction : tds -> AstSyntax.fonction -> AstTds.fonction *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre : la fonction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme la fonction
en une fonction de type AstTds.fonction *)
(* Erreur si mauvaise utilisation des identifiants *)
(* analyse_tds_fonction : tds -> AstSyntax.fonction -> AstTds.fonction *)
let analyse_tds_fonction maintds (AstSyntax.Fonction (t, n, lp, li)) =
  (* 1. Vérifier qu'il n'existe pas déjà une fonction (ou autre chose) de même nom
        dans la TDS globale *)
  begin
    match chercherLocalement maintds n with
    | Some _ ->
        (* On a déjà quelque chose qui s'appelle n au niveau global *)
        raise (DoubleDeclaration n)

    | None ->
        (* 2. Créer l'information associée à la fonction *)
        let ltypes_params = List.map (fun (is_ref, tp, _) -> (is_ref, tp)) lp in
        let info_fun = InfoFun (n, t, ltypes_params) in
        let ia_fun = info_to_info_ast info_fun in

        (* 3. Ajouter la fonction dans la TDS globale (maintds).
              Très important : ça permet la récursivité. *)
        ajouter maintds n ia_fun;

        (* 4. Créer une TDS fille pour le corps de la fonction.
              Cette TDS voit : les paramètres + les variables locales de la fonction,
              et, par la TDS mère, les autres fonctions globales. *)
        let tds_fonction = creerTDSFille maintds in

        (* 5. Ajouter les paramètres dans la TDS de la fonction *)
        let nlp =
          List.map
            (fun (is_ref, tp, nom_param) ->
              (* Vérifier qu'il n'y a pas déjà un paramètre de même nom
                  (ou une variable locale déjà ajoutée) dans cette TDS de fonction *)
              match chercherLocalement tds_fonction nom_param with
              | Some _ ->
                  raise (DoubleDeclaration nom_param)
              | None ->
                  (* Créer l'info pour le paramètre : c'est une variable locale avec un type. *)
                  let info_param = InfoVar (nom_param, Undefined, 0, "", is_ref) in
                  let ia_param = info_to_info_ast info_param in
                  (* Ajout dans la TDS locale de la fonction *)
                  ajouter tds_fonction nom_param ia_param;
                  (* On renvoie (is_ref, type, info_ast) pour construire l'AstTds.fonction *)
                  (is_ref, tp, ia_param)
            )
            lp
        in

        (* 6. Analyser le corps de la fonction.
              On passe Some ia_fun pour que les 'return' sachent à QUELLE fonction
              ils appartiennent. *)
        let nli = analyse_tds_bloc tds_fonction (Some ia_fun) li in

        (* 7. Construire le nœud de fonction dans l'AST TDS *)
        AstTds.Fonction (t, ia_fun, nlp, nli)
  end

(* analyser : AstSyntax.programme -> AstTds.programme *)
(* Paramètre : le programme à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le programme
en un programme de type AstTds.programme *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyser (AstSyntax.Programme (enums, fonctions, prog)) =
  let tds = creerTDSMere () in
  (* Analyser les enums en premier pour qu'ils soient disponibles dans tout le programme *)
  List.iter (analyse_tds_enum tds) enums;
  (* Analyser les fonctions *)
  let nf = List.map (analyse_tds_fonction tds) fonctions in
  (* Analyser le programme principal *)
  let nb = analyse_tds_bloc tds None prog in
  AstTds.Programme (nf,nb)
