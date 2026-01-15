open Rat
open Compilateur

let runtamcmde = "java -jar ../../runtam.jar"

let runtamcode cmde ratfile =
  let tamcode = compiler ratfile in
  let (tamfile, chan) = Filename.open_temp_file "test" ".tam" in
  output_string chan tamcode;
  close_out chan;
  let ic = Unix.open_process_in (cmde ^ " " ^ tamfile) in
  let printed = input_line ic in
  close_in ic;
  Sys.remove tamfile;
  String.trim printed

let runtam ratfile =
  print_string (runtamcode runtamcmde ratfile)

let pathFichiersRat = "../../../../../tests/tam/enums/fichiersRat/"

let%expect_test "enum_affichage" =
  runtam (pathFichiersRat^"enum_affichage.rat");
  [%expect{| 012 |}]

let%expect_test "enum_egalite" =
  runtam (pathFichiersRat^"enum_egalite.rat");
  [%expect{| falsetrue |}]

let%expect_test "enum_testegalite" =
  runtam (pathFichiersRat^"enum_testegalite.rat");
  [%expect{| falsetrue |}]