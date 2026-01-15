open Rat
open Compilateur
open Passe

(* Return la liste des adresses des variables d'un programme RAT *)
let getListeDep ratfile =
  let input = open_in ratfile in
  let filebuf = Lexing.from_channel input in
  try
    let ast = Parser.main Lexer.token filebuf in
    let past = CompilateurRat.calculer_placement ast in
    let listeAdresses = VerifPlacement.analyser past in
    listeAdresses
  with
  | Lexer.Error _ as e ->
      report_error ratfile filebuf "lexical error (unexpected character).";
      raise e
  | Parser.Error as e ->
      report_error ratfile filebuf "syntax error.";
      raise e

(* teste si dans le fichier fichier, dans la fonction fonction (main pour programme principal)
la occ occurence de la variable var a l'adresse dep[registre]
*)
let test fichier fonction (var,occ) (dep,registre) =
  let l = getListeDep fichier in
  let lmain = List.assoc fonction l in
  let rec aux i lmain =
    if i=1
    then
      let (d,r) = List.assoc var lmain in
      (d=dep && r=registre)
    else
      aux (i-1) (List.remove_assoc var lmain)
  in aux occ lmain

(****************************************)
(** Chemin d'accès aux fichiers de test *)
(****************************************)

let pathFichiersRat = "../../../../../tests/placement/pointeurs/fichiersRat/"

(**********)
(*  TESTS *)
(**********)

let%test "ptr_main_x" =
  test (pathFichiersRat^"test1.rat") "main" ("x",1) (0, "SB")
|| test (pathFichiersRat^"test1.rat") "main" ("x",1) (0, "LB")

let%test "ptr_main_p" =
  test (pathFichiersRat^"test1.rat") "main" ("p",1) (1, "SB")
|| test (pathFichiersRat^"test1.rat") "main" ("p",1) (1, "LB")

let%test "ptr_main_q" =
  test (pathFichiersRat^"test1.rat") "main" ("q",1) (2, "SB")
|| test (pathFichiersRat^"test1.rat") "main" ("q",1) (2, "LB")

let%test "ptr_main_y" =
  test (pathFichiersRat^"test1.rat") "main" ("y",1) (3, "SB")
|| test (pathFichiersRat^"test1.rat") "main" ("y",1) (3, "LB")

let%test "ptr_get_p" =
  test (pathFichiersRat^"test1.rat") "get" ("p",1) (-1, "LB")

let%test "ptr_get_v" =
  test (pathFichiersRat^"test1.rat") "get" ("v",1) (3, "LB")
