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

let pathFichiersRat = "../../../../../tests/tam/integration/fichiersRat/"

let%expect_test "enum_pointeurs" =
  runtam (pathFichiersRat^"enum_pointeurs.rat");
  [%expect{| 0 |}]

let%expect_test "ref_pointeurs" =
  runtam (pathFichiersRat^"ref_pointeurs.rat");
  [%expect{| 100 |}]

let%expect_test "proc_enums" =
  runtam (pathFichiersRat^"proc_enums.rat");
  [%expect{| 01 |}]
