module Uncurry exposing (..)

import Common exposing (Name)
import Dict exposing (Dict)


type Type
    = TypeFunction Type
    | TypePartial Type Type
    | TypePrimitive Common.PrimitiveType
    | TypeTuple2 Type Type
    | TypeTuple3 Type Type Type


type alias Expr =
    ( Expr_, Type )


type Expr_
    = Literal Common.Literal
    | Var Name
    | Binop Common.Binop Expr Expr
    | CallTotal
        { functionName : Name
        , arguments : List Expr
        }
    | CallPartial
        { functionName : Name
        , partialArguments : List Expr
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
                |> uncurryFunction body

        Flattened.Var functionName ->
            { accum | functionName = functionName }
                uncurry

        _ ->
            Debug.todo <| Debug.log "" expr_ ++ " is not callable, this shouldn't happen!!!"



-- Uncurry Expr


uncurry : Flattened.Expr -> Expr
uncurry ( expr_, type_ ) =
    let
        andType : Expr_ -> Expr
        andType e =
            ( e, uncurryType type_ )
    in
    case expr_ of
        Flattened.Call { fn, argument } ->
            let
                { functionName, arguments, bindings } =
                    uncurryFunction fn (initUncurryFunctionAcc argument)

                ( call, callType ) =
                    if typeArity type_ == List.length arguments then
                        ( CallTotal
                            { functionName = functionName
                            , arguments = List.reverse arguments
                            }
                        , uncurryType type_
                        )

                    else
                        ( CallPartial
                            { functionName = functionName
                            , partialArguments = List.reverse arguments
                            }
                          --The first "previous type" will be discarded anyway
                        , toPartialType (TypePrimitive Common.TypeUnit) type_
                        )
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
                |> andType

        Flattened.Var n ->
            Var n
                |> andType

        Flattened.Binop op a b ->
            Binop op (uncurry a) (uncurry b)
                |> andType

        Flattened.If { test, then_, else_ } ->
            If
                { test = uncurry test
                , then_ = uncurry then_
                , else_ = uncurry else_
                }
                |> andType

        Flattened.Let { bindings, body } ->
            Let
                { bindings = Dict.map (\bindingName bindingExpr -> uncurry bindingExpr) bindings
                , body = uncurry body
                }
                |> andType

        Flattened.Tuple a b ->
            Tuple2 (uncurry a) (uncurry b)
                |> andType

        Flattened.Tuple3 a b c ->
            Tuple3 (uncurry a) (uncurry b) (uncurry c)
                |> andType


toPartialType : Flattened.Type -> Flattened.Type -> Type
toPartialType previousArgumentType currentType =
    case currentType of
        Flattened.TypeFunction inType outType ->
            TypeFunction (uncurryType inType) (toPartialType currentType outType)

        _ ->
            TypePartial (uncurryType previousArgumentType) (uncurryType currentType)



-- Uncurry Type


uncurryType : Flattened.Type -> Type
uncurryType type_ =
    case type_ of
        Flattened.TypeFunction from to ->
            [ from ]
                |> uncurryFunctionType to
                |> List.reverse
                |> TypeFunction

        Flattened.TypePrimitive p ->
            TypePrimitive p

        Flattened.TypeTuple2 a b ->
            TypeTuple2 (uncurryType a) (uncurryType b)

        Flattened.TypeTuple3 a b c ->
            TypeTuple3 (uncurryType a) (uncurryType b) (uncurryType c)


uncurryFunctionType : Flattened.Type -> List Type -> List Type
uncurryFunctionType t ts =
    case t of
        Flattened.TypeFunction arg out ->
            uncurryFunctionType out (arg :: ts)

        _ ->
            uncurryType t :: ts



-- Create types


extractConstructors : Expr -> List ( Name, Type ) -> List ( Name, Type )
extractConstructors ( expr_, type_ ) cs =
    case expr_ of
        Binop _ a b ->
            cs
                |> extractConstructors a
                |> extractConstructors b

        CallTotal { fn, arguments } ->
            List.foldl extractConstructors cs arguments

        CallPartial { functionName, partialArguments } ->
            ( functionName, type_ ) :: cs

        If { test, then_, else_ } ->
            cs
                |> extractConstructors a
                |> extractConstructors b

        Let { bindings, body } ->
            bindings
                |> Dict.values
                |> List.foldl extractConstructors (extractConstructors body cs)

        Tuple a b ->
            cs
                |> extractConstructors a
                |> extractConstructors b

        Tuple3 a b c ->
            cs
                |> extractConstructors a
                |> extractConstructors b
                |> extractConstructors c
