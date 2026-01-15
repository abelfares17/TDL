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

let pathFichiersRat = "../../../../../tests/tam/pointeurs/fichiersRat/"

let%expect_test "alloc_deref" =
  runtam (pathFichiersRat^"alloc_deref.rat");
  [%expect{| 42 |}]

let%expect_test "adresse_modif" =
  runtam (pathFichiersRat^"adresse_modif.rat");
  [%expect{| 10 |}]
