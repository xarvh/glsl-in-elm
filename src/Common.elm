module Common exposing (..)


type alias Name
    = String


type Literal
    = Unit
    | Int Int
    | Float Float
    | Bool Bool


type PrimitiveType
    = TypeUnit
    | TypeInt
    | TypeFloat
    | TypeBool


type Binop
    = Plus
