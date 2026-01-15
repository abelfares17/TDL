open Rat
open Compilateur

exception ErreurNonDetectee

let pathFichiersRat = "../../../../../tests/type/ref/fichiersRat/"

(* Tests positifs *)
let%test_unit "ref_compatible"=
  let _ = compiler (pathFichiersRat^"ref_compatible.rat") in ()

let%test_unit "ref_pointeur"=
  let _ = compiler (pathFichiersRat^"ref_pointeur.rat") in ()
