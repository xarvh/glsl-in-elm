module Flattened exposing (..)


type alias Expr =
    ( Expr_, Type )


type alias VarName =
    String


type Expr_
    = Int Int
    | Float Float
    | Bool Bool
    | Var VarName
    | Plus Expr Expr
    | Cons Expr Expr
    | Call
        { fn : Expr
        , argument : Expr
        }
    | If
        { test : Expr
        , then_ : Expr
        , else_ : Expr
        }
    | Let
        { bindings : Dict VarName (Binding Expr)
        , body : Expr
        }
    | Unit
    | Tuple Expr Expr
    | Tuple3 Expr Expr Expr
