open Rat
open Compilateur
open Exceptions

exception ErreurNonDetectee

let pathFichiersRat = "/Users/mhandfares/Desktop/N7/My_Course/2A/TDL/sourceEtu/tests/gestion_id/ref/fichiersRat/"

(* Tests positifs *)
let%test_unit "ref_simple"=
  let _ = compiler (pathFichiersRat^"ref_simple.rat") in ()

let%test_unit "ref_mix"=
  let _ = compiler (pathFichiersRat^"ref_mix.rat") in ()

(* Tests négatifs *)
let%test_unit "ref_inexistant" =
  try
    let _ = compiler (pathFichiersRat^"ref_inexistant.rat") in
    raise ErreurNonDetectee
  with
  | IdentifiantNonDeclare "inexistant" -> ()
