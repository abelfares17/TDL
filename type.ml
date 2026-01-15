type typ = Bool | Int | Rat | Void | Enum of string | Pointeur of typ | Undefined

let rec string_of_type t =
  match t with
  | Bool ->  "Bool"
  | Int  ->  "Int"
  | Rat  ->  "Rat"
  | Void -> "Void"
  | Enum nom -> nom
  | Pointeur tp -> (string_of_type tp) ^ "*"
  | Undefined -> "Undefined"


let rec est_compatible t1 t2 =
  match t1, t2 with
  | Bool, Bool -> true
  | Int, Int -> true
  | Rat, Rat -> true
  | Enum nom1, Enum nom2 -> nom1 = nom2
  | Pointeur _, Pointeur Undefined -> true  (* null compatible avec tout pointeur *)
  | Pointeur Undefined, Pointeur _ -> true  (* null compatible avec tout pointeur *)
  | Pointeur tp1, Pointeur tp2 -> est_compatible tp1 tp2
  | _ -> false 

let%test _ = est_compatible Bool Bool
let%test _ = est_compatible Int Int
let%test _ = est_compatible Rat Rat
let%test _ = not (est_compatible Int Bool)
let%test _ = not (est_compatible Bool Int)
let%test _ = not (est_compatible Int Rat)
let%test _ = not (est_compatible Rat Int)
let%test _ = not (est_compatible Bool Rat)
let%test _ = not (est_compatible Rat Bool)
let%test _ = not (est_compatible Undefined Int)
let%test _ = not (est_compatible Int Undefined)
let%test _ = not (est_compatible Rat Undefined)
let%test _ = not (est_compatible Bool Undefined)
let%test _ = not (est_compatible Undefined Int)
let%test _ = not (est_compatible Undefined Rat)
let%test _ = not (est_compatible Undefined Bool)

let est_compatible_list lt1 lt2 =
  try
    List.for_all2 est_compatible lt1 lt2
  with Invalid_argument _ -> false

let%test _ = est_compatible_list [] []
let%test _ = est_compatible_list [Int ; Rat] [Int ; Rat]
let%test _ = est_compatible_list [Bool ; Rat ; Bool] [Bool ; Rat ; Bool]
let%test _ = not (est_compatible_list [Int] [Int ; Rat])
let%test _ = not (est_compatible_list [Int] [Rat ; Int])
let%test _ = not (est_compatible_list [Int ; Rat] [Rat ; Int])
let%test _ = not (est_compatible_list [Bool ; Rat ; Bool] [Bool ; Rat ; Bool ; Int])

let rec getTaille t =
  match t with
  | Int -> 1
  | Bool -> 1
  | Rat -> 2
  | Void -> 0
  | Enum _ -> 1
  | Pointeur _ -> 1  (* Une adresse = 1 mot *)
  | Undefined -> 0
  
let%test _ = getTaille Int = 1
let%test _ = getTaille Bool = 1
let%test _ = getTaille Rat = 2
