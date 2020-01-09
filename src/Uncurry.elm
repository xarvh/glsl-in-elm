module Uncurry exposing (..)

import Common exposing (Name)
import Dict exposing (Dict)


type Type
    = Var Int
    | Function (List Type)
    | Int
    | Float
    | Bool
    | Tuple Type Type
    | Tuple3 Type Type Type


type alias Expr =
    ( Expr_, Type )


type Expr_
    = Literal Common.Literal
    | Var Name
    | Binop Common.Binop Expr Expr
    | Call
        { fn : Name
        , arguments : List Expr
        }
    | If
        { test : Expr
        , then_ : Expr
        , else_ : Expr
        }
    | Let
        { bindings : Dict Name Expr
        , body : Expr
        }
    | Tuple Expr Expr
    | Tuple3 Expr Expr Expr



-- Uncurry function


type alias UncurryFunctionAcc =
    { functionName : Name
    , arguments : List Expr
    , bindings : Dict Name Expr
    }


initUncurryFunctionAcc : Expr -> UncurryFunctionAcc
initUncurryFunctionAcc firstArgument =
    { functionName = ""
    , arguments = [ firstArgument ]
    , bindings = Dict.empty
    }


uncurryFunction : Expr -> UncurryFunctionAcc -> UncurryFunctionAcc
uncurryFunction ( fnExpr_, type_ ) accum =
    case expr_ of
        Flattened.Call { fn, argument } ->
            { accum | arguments = argument :: accum.arguments }
                |> uncurryFunction fn

        Flattened.LetIn { bindings, body } ->
            { accum | bindings = Dict.union bindings accum.bindings }
                |> straightenFunction body

        Flattened.Var functionName ->
            { accum | functionName = functionName }
                straighten

        _ ->
            Debug.todo <| Debug.log "" expr_ ++ " is not callable, this shouldn't happen!!!"


straighten : Flattened.Expr -> Expr
straighten ( expr_, type_ ) =
    case expr_ of
        Flattened.Call { fn, argument } ->
            let
                { functionName, arguments, bindings } =
                    uncurryFunction fn (initUncurryFunctionAcc argument)

                call =
                    Call
                        { functionName = functionName
                        , arguments = arguments
                        }
            in
            if bindings == Dict.empty then
                call

            else
                Let
                    { bindings = bindings
                    , body = call
                    }

        Flattened.Literal l ->
            Literal l

        Flattened.Var n ->
            Var n

        Flattened.Binop op a b ->
            Binop op (uncurry a) (uncurry b)

        Flattened.If { test, then_, else_ } ->
            If
                { test = uncurry test
                , then_ = uncurry then_
                , else_ = uncurry else_
                }

        Flattened.Let { bindings, body } ->
            Let
                { bindings = Dict.map (\k -> uncurry)
                , body = uncurry body
                }

        Flattened.Tuple a b ->
            ( uncurry a, uncurry b )

        Flattened.Tuple3 a b c ->
            ( uncurry a, uncurry b, uncurry c )
