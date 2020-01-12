module Common exposing (..)


type alias Name =
    String


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


moduleAndNameToName : { module_ : String, name : String } -> String
moduleAndNameToName { module_, name } =
    String.replace "." "_" module_ ++ "_" ++ name
