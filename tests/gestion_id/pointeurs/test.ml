open Rat
open Compilateur
open Exceptions

exception ErreurNonDetectee

let pathFichiersRat = "/Users/mhandfares/Desktop/N7/My_Course/2A/TDL/sourceEtu/tests/gestion_id/pointeurs/fichiersRat/"

(* Tests positifs *)
let%test_unit "pointeur_simple"=
  let _ = compiler (pathFichiersRat^"pointeur_simple.rat") in ()

let%test_unit "adresse_variable"=
  let _ = compiler (pathFichiersRat^"adresse_variable.rat") in ()

(* Tests négatifs *)
let%test_unit "adresse_inexistant" =
  try
    let _ = compiler (pathFichiersRat^"adresse_inexistant.rat") in
    raise ErreurNonDetectee
  with
  | IdentifiantNonDeclare "inexistant" -> ()
