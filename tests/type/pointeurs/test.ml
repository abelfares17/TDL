open Rat
open Compilateur
open Exceptions

exception ErreurNonDetectee

let pathFichiersRat = "/Users/mhandfares/Desktop/N7/My_Course/2A/TDL/sourceEtu/tests/type/pointeurs/fichiersRat/"

(* Tests positifs *)
let%test_unit "null_compatible"=
  let _ = compiler (pathFichiersRat^"null_compatible.rat") in ()

let%test_unit "new_type"=
  let _ = compiler (pathFichiersRat^"new_type.rat") in ()

let%test_unit "deref_lecture"=
  let _ = compiler (pathFichiersRat^"deref_lecture.rat") in ()
