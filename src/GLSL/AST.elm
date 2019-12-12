module GLSL.AST exposing (..)


type alias Name =
    String


type alias EmbeddedBlock =
    { maybePrecision : Precision
    , attributes : List ( Type, Name )
    , uniforms : List ( Type, Name )
    , varyings : List ( Type, Name )
    , declarations : List Declaration
    }


type alias Declaration =
    { type_ : Type
    , name : Name
    , body : DeclarationBody
    }


type DeclarationBody
    = Variable
        { maybeInit : Expr
        }
    | Function
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
    | ForLoop {}
    | If {}
    | Return Expr


type Expr
    = Literal Literal
    | Unary Unary Expr
    | Infix Infix Expr Expr
    | FunctionCall Name (List Expr)


type Literal
    = LiteralInt Int
    | LiteralFloat Float
    | LiteralBool Bool


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
