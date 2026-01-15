open Rat
open Compilateur
open Exceptions

exception ErreurNonDetectee

let pathFichiersRat = "../../../../../tests/gestion_id/enums/fichiersRat/"

(* Tests positifs *)
let%test_unit "enum_simple"=
  let _ = compiler (pathFichiersRat^"enum_simple.rat") in ()

let%test_unit "enums_multiples"=
  let _ = compiler (pathFichiersRat^"enums_multiples.rat") in ()

(* Tests négatifs *)
let%test_unit "enum_type_duplique" =
  try
    let _ = compiler (pathFichiersRat^"enum_type_duplique.rat") in
    raise ErreurNonDetectee
  with
  | DoubleDeclaration "Couleur" -> ()

let%test_unit "enum_valeur_dupliquee" =
  try
    let _ = compiler (pathFichiersRat^"enum_valeur_dupliquee.rat") in
    raise ErreurNonDetectee
  with
  | DoubleDeclaration "Commun" -> ()

let%test_unit "enum_valeur_inexistante" =
  try
    let _ = compiler (pathFichiersRat^"enum_valeur_inexistante.rat") in
    raise ErreurNonDetectee
  with
  | IdentifiantNonDeclare "Bleu" -> ()
