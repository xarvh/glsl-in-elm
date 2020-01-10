module Flatten exposing (..)

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
    | LetIn
        { bindings : Dict Name Expr
        , body : Expr
        }
    | Tuple2 Expr Expr
    | Tuple3 Expr Expr Expr


test =
    let
        bool =
            TypePrimitive Common.TypeBool

        int =
            TypePrimitive Common.TypeInt
    in
    ( If
        { test = ( Var "someBool", bool )
        , then_ = ( Literal <| Common.Int 1, int )
        , else_ =
            ( Call
                { fn =
                    ( Call
                        { fn = ( Var "meh", TypeFunction int (TypeFunction int int) )
                        , argument = ( Var "innerArg", int )
                        }
                    , TypeFunction int int
                    )
                , argument = ( Var "outerArg", int )
                }
            , int
            )
        }
    , int
    )
