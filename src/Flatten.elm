module Flatten exposing (..)

-- import Elm.Data.Binding exposing (Binding)

import Common exposing (Name)
import Dict exposing (Dict)
import Elm.AST.Typed.Unwrapped as Elm
import Set exposing (Set)


type Type
    = TypePrimitive Common.PrimitiveType
    | TypeFunction Type Type
    | TypeTuple2 Type Type
    | TypeTuple3 Type Type Type


type alias Expr =
    ( Expr_, Type )


type Expr_
    = Literal Common.Literal
    | Var Name
    | Binop Common.Binop Expr Expr
    | Call
        { fn : Expr
        , argument : Expr
        }
    | If
        { test : Expr
        , then_ : Expr
        , else_ : Expr
        }
    | LetIn
        { bindings : Dict Name Expr
        , body : Expr
        }
    | Tuple2 Expr Expr
    | Tuple3 Expr Expr Expr



-- Flatten


type alias Accum =
    { nextGeneratedName : Int
    , generatedFunctions : List ( Name, List ( Name, Type ), Expr )

    -- When we find a lambda, should we start a new function or just append a new arg?
    , collectingArguments : Bool

    -- Globals are available to every function, no matter its scope
    , globals : Set Name

    --
    , arguments : List ( Name, Type )

    --
    , letInNames : Set Name

    -- These are the names that appear in the function or its children but are declared in an ancestor scope
    -- It's important to track these because when we extract a function outside a scope, they will need to be passed
    -- as arguments.
    , inheritedNames : Dict Name Type
    }


flattenFunction : Elm.Expr -> Accum -> ( Expr, Accum )
flattenFunction ( expr_, type_ ) acc =
    let
        andType ( e, acc ) =
            ( ( e, translateType type_ ), acc )
    in
    case expr_ of
        Elm.Int n ->
            andType
                ( Common.Int n |> Literal
                , acc
                )

        Elm.Float n ->
            andType
                ( Common.Float n |> Literal
                , acc
                )

        Elm.Char Char ->
            Debug.todo "no chars"

        Elm.String String ->
            Debug.todo "no strings"

        Elm.Bool b ->
            andType
                ( Common.Bool b |> Literal
                , acc
                )

        Elm.Var moduleAndName ->
            acc
                |> addToInherited (moduleAndNameToName moduleAndName) type_
                |> andType

        Elm.Argument name ->
            acc
                |> addToInherited name type_
                |> andType

        Elm.Plus a b ->
            let
                acc0 =
                    { acc | collectingArguments = False }

                ( aExpr, acc1 ) =
                    flattenFunction a acc0

                ( bExpr, acc2 ) =
                    flattenFunction b acc1
            in
            andType
                ( Binop Common.Plus aExpr bExpr
                , acc2
                )

        Elm.Cons Expr Expr ->
            Debug.todo "no lists"

        Elm.Lambda { argument, body } ->
            let
                argumentType =
                    getArgumentType type_

                argumentAndType =
                    ( argument, argumentType )
            in
            if acc.collectingArguments then
                -- We are still traversing the lambdas, add arguments
                { acc | arguments = argumentAndType :: acc.arguments }
                    |> flattenFunction body

            else
                let
                    -- This is a new function declaration, reset the accumulator accordingly
                    ( functionBody, lambdaAcc ) =
                        { acc
                            | arguments = [ argumentAndType ]
                            , letInNames = Dict.empty
                            , inheritedNames = Set.empty
                            , collectingArguments = True
                            , nextGeneratedName = acc.nextGeneratedName + 1
                        }
                            |> flattenFunction body

                    additionalArguments =
                        lambdaAcc.inheritedNames
                            |> Dict.toList
                            |> List.sortBy Tuple.first

                    -- add all inherited names as new function arguments
                    functionArguments =
                        additionalArguments ++ lambdaAcc.arguments

                    functionName =
                        "f" ++ String.fromInt lambdaAcc.nextGeneratedName

                    newFunction =
                        ( functionName, functionArguments, functionBody )

                    newAcc =
                        { acc
                            | nextGeneratedName = lambdaAcc.nextGeneratedName + 1
                            , generatedFunctions = newFunction :: lambdaAcc.generatedFunctions
                        }

                    -- add new arguments to type
                    functionType =
                        List.foldl (\( argName, argType ) funType -> TypeFunction argType funType) (translateType type_) additionalArguments

                    addArgumentToCall ( argName, argType ) ( fnExpr, fnType ) =
                        ( Call
                            { fn = ( fnExpr, fnType )
                            , argument = argName
                            }
                        , TypeFunction argType typ
                        )

                    -- add new arguments to call
                    callExpr =
                        List.foldl addArgumentToCall ( Var functionName, functionType ) additionalArguments
                in
                ( callExpr
                , newAcc
                )

        Elm.Call { fn, argument } ->
            recurse

        Elm.If { test, then_, else_ } ->
            recurse

        Elm.Let { bindings, body } ->
            add to letInNames

        Elm.List (List Expr) ->
            Debug.todo "no lists"

        Elm.Unit ->
            ( Literal Common.Unit
            , acc
            )

        Elm.Tuple a b ->
            recurse

        Elm.Tuple3 a b c ->
            recurse


addToInherited : Name -> Elm.Type -> Acc -> ( Expr_, Acc )
addToInherited name elmType acc =
    let
        type_ =
            translateType elmType

        isDeclaredWithin =
            Dict.member name acc.letInNames || List.member name acc.arguments

        isGlobal =
            Set.member name acc.globals

        isInherited =
            not isDeclaredWithin && not isGlobal
    in
    ( ( Var name, type_ )
    , if isInherited then
        { acc | inheritedNames = Dict.insert name type_ acc.inheritedNames }

      else
        acc
    )
