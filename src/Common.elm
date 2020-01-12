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


opToString : Binop -> String
opToString op =
    case op of
        Plus ->
            "+"


literalToString : Literal -> String
literalToString l =
    case l of
        Unit ->
            "()"

        Int n ->
            String.fromInt n

        Float n ->
            String.fromFloat n

        Bool b ->
            if b then
                "True"

            else
                "False"


primitiveTypeToString : PrimitiveType -> String
primitiveTypeToString p =
    case p of
        TypeUnit ->
            "()"

        TypeInt ->
            "Int"

        TypeFloat ->
            "Float"

        TypeBool ->
            "Bool"
