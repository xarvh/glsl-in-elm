module Flattened exposing (..)

import Common exposing (Name)
import Dict exposing (Dict)


type Type
    = TypePrimitive Common.PrimitiveType
    | TypeFunction Type Type
    | TypeTuple2 Type Type
    | TypeTuple3 Type Type Type


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
    | Tuple2 Expr Expr
    | Tuple3 Expr Expr Expr
