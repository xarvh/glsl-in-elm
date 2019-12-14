module GLSL.AST exposing (..)


type alias Name =
    String


type alias EmbeddedBlock =
    { maybePrecision : Precision
    , attributes : List ( Type, Name )
    , uniforms : List ( Type, Name )
    , varyings : List ( Type, Name )
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
        { args : List ( Type, Name )
        , body : List Statement
        }


type Type
    = Int
    | Float
    | Bool
    | Vec1
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
