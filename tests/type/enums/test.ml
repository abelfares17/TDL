open Rat
open Compilateur
open Exceptions

exception ErreurNonDetectee

let pathFichiersRat = "../../../../../tests/type/enums/fichiersRat/"

(* Tests positifs *)
let%test_unit "enum_affectation"=
  let _ = compiler (pathFichiersRat^"enum_affectation.rat") in ()

let%test_unit "enum_egalite"=
  let _ = compiler (pathFichiersRat^"enum_egalite.rat") in ()

(* Tests négatifs *)
let%test_unit "enum_affectation_differents" =
  try
    let _ = compiler (pathFichiersRat^"enum_affectation_differents.rat") in
    raise ErreurNonDetectee
  with
  | TypeInattendu _ -> ()

let%test_unit "enum_a_int" =
  try
    let _ = compiler (pathFichiersRat^"enum_a_int.rat") in
    raise ErreurNonDetectee
  with
  | TypeInattendu _ -> ()
