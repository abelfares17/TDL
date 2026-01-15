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

let pathFichiersRat = "../../../../../tests/tam/procedures/fichiersRat/"

let%expect_test "proc_simple" =
  runtam (pathFichiersRat^"proc_simple.rat");
  [%expect{| 42 |}]

let%expect_test "proc_params" =
  runtam (pathFichiersRat^"proc_params.rat");
  [%expect{| 1020 |}]

let%expect_test "return_anticipe" =
  runtam (pathFichiersRat^"return_anticipe.rat");
  [%expect{| 1 |}]
