open Rat
open Compilateur
open Exceptions

exception ErreurNonDetectee

let pathFichiersRat = "/Users/mhandfares/Desktop/N7/My_Course/2A/TDL/sourceEtu/tests/type/ref/fichiersRat/"

(* Tests positifs *)
let%test_unit "ref_compatible"=
  let _ = compiler (pathFichiersRat^"ref_compatible.rat") in ()

let%test_unit "ref_pointeur"=
  let _ = compiler (pathFichiersRat^"ref_pointeur.rat") in ()
