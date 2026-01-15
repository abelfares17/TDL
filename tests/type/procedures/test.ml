open Rat
open Compilateur
open Exceptions

exception ErreurNonDetectee

let pathFichiersRat = "../../../../../tests/type/procedures/fichiersRat/"

(* Tests positifs *)
let%test_unit "return_void"=
  let _ = compiler (pathFichiersRat^"return_void.rat") in ()

let%test_unit "proc_bons_types"=
  let _ = compiler (pathFichiersRat^"proc_bons_types.rat") in ()

(* Tests négatifs *)
let%test_unit "utiliser_resultat_proc" =
  try
    let _ = compiler (pathFichiersRat^"utiliser_resultat_proc.rat") in
    raise ErreurNonDetectee
  with
  | TypeInattendu _ -> ()
