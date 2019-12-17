module GLSL.AST exposing (..)


type alias Name =
    String


type alias TypeAndName =
    ( Type, Name )


type alias EmbeddedBlock =
    { maybePrecision : Precision
    , attributes : List TypeAndName
    , uniforms : List TypeAndName
    , varyings : List TypeAndName
    , mainDeclaration : DeclarationBody
    , otherDeclarations : List Declaration
    }


type alias Declaration =
    { type_ : Type
    , name : Name
    , body : DeclarationBody
    }


type DeclarationBody
    = DeclarationVariable
        { maybeInit : Maybe Expr
        }
    | DeclarationFunction
        { args : List TypeAndName
        , statements : List Statement
        }


type Type
    = Int
    | Float
    | Bool
    | Vec2
    | Vec3
    | Vec4
    | Mat4
    | Struct { name : Name }


type Statement
    = StatementDeclaration Declaration
    | Assign Name Expr
    | ForLoop {}
    | If
        { test : Expr
        , then_ : Statement
        , else_ : Maybe Statement
        }
    | Return Expr


type Expr
    = LiteralInt Int
    | LiteralFloat Float
    | LiteralBool Bool
    | Variable Name
    | Unary Unary Expr
    | Infix Infix Expr Expr
    | FunctionCall Name (List Expr)


type Unary
    = Not
    | Negate


type Infix
    = Add
    | Subtract
    | Multiply
    | Divide


type Precision
    = Precision



----
---- To String
----


addIndent : String -> String
addIndent =
    (++) "  "


declarationToString : Declaration -> String
declarationToString decl =
    [ typeToString decl.type_
    , " "
    , decl.name
    , case decl.body of
        DeclarationVariable { maybeInit } ->
            (maybeInit
                |> Maybe.map expressionToString
                |> Maybe.withDefault ""
            )
                ++ ";"

        DeclarationFunction { args, statements } ->
            [ "("
            , args
                |> List.map typeAndNameToString
                |> String.join ", "
            , ") {\n"
            , statements
                |> List.map (statementToString >> addIndent)
                |> String.join "\n"
            , "\n}\n\n"
            ]
                |> String.join ""
    ]
        |> String.join ""


typeToString : Type -> String
typeToString type_ =
    case type_ of
        Int ->
            "int"

        Float ->
            "float"

        Bool ->
            "bool"

        Vec2 ->
            "vec2"

        Vec3 ->
            "vec3"

        Vec4 ->
            "vec4"

        Mat4 ->
            "mat4"

        Struct _ ->
            Debug.todo "TODO"


typeAndNameToString : TypeAndName -> String
typeAndNameToString ( type_, name ) =
    typeToString type_ ++ " " ++ name


expressionToString : Expr -> String
expressionToString expr =
    "EXPR"


statementToString : Statement -> String
statementToString s =
    case s of
        StatementDeclaration declaration ->
            declarationToString declaration

        Assign name expr ->
            name ++ " = " ++ expressionToString expr ++ ";"

        ForLoop {} ->
            Debug.todo "NI"

        If { test, then_, else_ } ->
            Debug.todo "if"

        Return expr ->
            "return " ++ expressionToString expr ++ ";"
