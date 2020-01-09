module Common exposing (..)


type Name
    = String


type Literal
    = Unit
    | Int Int
    | Float Float
    | Bool Bool


type Binop
    = Plus
