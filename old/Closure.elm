module Main exposing (Expr, Expr_(..), Scope(..))


type alias Expr =
    ( Expr_, Type )


type Expr_
    = Int Int
    | Float Float
    | Bool Bool
    | Var { name : VarName, scope : Scope }
    | Plus Expr Expr
    | FunctionDeclaration
        { arguments : List ( Type, VarName )
        , body : Expr
        }
    | Call
        { functionName : Expr
        , args : List Expr
        , haveEnoughArgs : Bool
        , closureState : List ( VarName, Expr )
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
    | Unit
    | Tuple Expr Expr
    | Tuple3 Expr Expr Expr


type Scope
    = ScopeFunction
    | ScopeProgram


{-| I can declare a function inside a function

    => This can be easily inlined since it's how functions are declared in Elm AST anyway

-}
fun a =
    \x -> a * x


{-| The function uses a variable declared in some upstream let..in or function argument

    => We need to add a new argument to the function
    => All these arguments are declared at the point of (Elm side) function definition,
    so they can be arranged in a struct for convenience

    => if the function has enough argument, the resulting value is just the function's return value
    => if the function is only partially applied, the resulting value is a closure



    When a function is declared:
      Crawl the whole body of the function and pull out all the symbol references
      and the symbol declarations to figure out what is used of the upstream scopes
      => Optionally distinguish those used in the global scope

    Since Elm doesn't allow shadowing, this should be easy-ish


-}
blah =
    let
        v =
            something

        fun a =
            \x -> a * x * someUpperScopeValue
    in
    meh
