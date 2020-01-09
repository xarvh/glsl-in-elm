module Flattened exposing (..)

import Common exposing (Name)
import Dict exposing (Dict)


type alias Expr =
    ( Expr_, Type )


type Expr_
    = Literal Common.Literal
    | Var Name
    | Binop Common.Binop Expr Expr
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
    | Tuple Expr Expr
    | Tuple3 Expr Expr Expr
