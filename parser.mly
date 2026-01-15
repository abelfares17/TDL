/* Imports. */

%{

open Type
open Ast.AstSyntax
%}


%token <int> ENTIER
%token <string> ID
%token <string> TID
%token RETURN
%token ENUM
%token VIRG
%token PV
%token AO
%token AF
%token PF
%token PO
%token EQUAL
%token CONST
%token PRINT
%token IF
%token ELSE
%token WHILE
%token BOOL
%token INT
%token RAT
%token VOID
%token CO
%token CF
%token SLASH
%token NUM
%token DENOM
%token TRUE
%token FALSE
%token PLUS
%token MULT
%token INF
%token AMP
%token NULL
%token NEW
%token REF
%token EOF

(* Type de l'attribut synthétisé des non-terminaux *)
%type <programme> prog
%type <instruction list> bloc
%type <fonction> fonc
%type <instruction> i
%type <typ> typ
%type <bool*typ*string> param
%type <affectable> a
%type <argument> arg
%type <expression> e
%type <string * string list> enum_decl

(* Type et définition de l'axiome *)
%start <Ast.AstSyntax.programme> main

%%

main : lfi=prog EOF     {lfi}

prog : le=enum_decl* lf=fonc* ID li=bloc  {Programme (le,lf,li)}

enum_decl : ENUM nom=TID AO vals=separated_list(VIRG,TID) AF PV  {(nom,vals)}

fonc : t=typ n=ID PO lp=separated_list(VIRG,param) PF li=bloc {Fonction(t,n,lp,li)}

param :
| t=typ n=ID          {(false,t,n)}
| REF t=typ n=ID      {(true,t,n)}

bloc : AO li=i* AF      {li}

i :
| t=typ n=ID EQUAL e1=e PV          {Declaration (t,n,e1)}
| aff=a EQUAL e1=e PV               {Affectation (aff,e1)}
| CONST n=ID EQUAL e=ENTIER PV      {Constante (n,e)}
| PRINT e1=e PV                     {Affichage (e1)}
| IF exp=e li1=bloc ELSE li2=bloc   {Conditionnelle (exp,li1,li2)}
| WHILE exp=e li=bloc               {TantQue (exp,li)}
| RETURN exp=e PV                   {Retour (Some exp)}
| RETURN PV                         {Retour None}
| n=ID PO lp=separated_list(VIRG,arg) PF PV  {AppelProc (n,lp)}

typ :
| BOOL       {Bool}
| INT        {Int}
| RAT        {Rat}
| VOID       {Void}
| n=TID      {Enum n}
| t=typ MULT {Pointeur t}

a :
| n=ID                    {Ident n}
| PO MULT aff=a PF        {Deref aff}

arg :
| e=e                     {ArgNormal e}
| REF e=e                 {ArgRef e}

e :
| n=ID PO lp=separated_list(VIRG,arg) PF   {AppelFonction (n,lp)}
| CO e1=e SLASH e2=e CF   {Binaire(Fraction,e1,e2)}
| aff=a                   {Affectable aff}
| TRUE                    {Booleen true}
| FALSE                   {Booleen false}
| e=ENTIER                {Entier e}
| n=TID                   {IdentEnum n}
| NULL                    {Null}
| PO NEW t=typ PF         {New t}
| AMP n=ID                {Adresse n}
| NUM e1=e                {Unaire(Numerateur,e1)}
| DENOM e1=e              {Unaire(Denominateur,e1)}
| PO e1=e PLUS e2=e PF    {Binaire (Plus,e1,e2)}
| PO e1=e MULT e2=e PF    {Binaire (Mult,e1,e2)}
| PO e1=e EQUAL e2=e PF   {Binaire (Equ,e1,e2)}
| PO e1=e INF e2=e PF     {Binaire (Inf,e1,e2)}
| PO exp=e PF             {exp}


