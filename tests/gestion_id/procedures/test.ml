open Rat
open Compilateur
open Exceptions

exception ErreurNonDetectee

let pathFichiersRat = "../../../../..//tests/gestion_id/procedures/fichiersRat/"

(* Tests positifs *)
let%test_unit "proc_simple"=
  let _ = compiler (pathFichiersRat^"proc_simple.rat") in ()

let%test_unit "proc_params"=
  let _ = compiler (pathFichiersRat^"proc_params.rat") in ()

(* Tests négatifs *)
let%test_unit "proc_inexistante" =
  try
    let _ = compiler (pathFichiersRat^"proc_inexistante.rat") in
    raise ErreurNonDetectee
  with
  | IdentifiantNonDeclare "inexistante" -> ()
