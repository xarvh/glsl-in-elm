module Flatten exposing (..)

-- import Elm.Data.Binding exposing (Binding)

import Common exposing (Name)
import Dict exposing (Dict)
import Elm.AST.Typed.Unwrapped as Elm
import Elm.Data.Type as ElmT
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


type alias FunctionDefinition =
    Common.FunctionDefinition Type Expr



-- To String


functionToString : FunctionDefinition -> String
functionToString { name, args, expr } =
    let
        annotation =
            (List.map Tuple.second args ++ [ Tuple.second expr ])
                |> List.map typeToString
                |> String.join " -> "
    in
    String.join "\n"
        [ name ++ " : " ++ annotation
        , name ++ " " ++ String.join " " (List.map Tuple.first args) ++ " = "
        , "    " ++ exprToString expr
        ]


typeToString : Type -> String
typeToString t =
    case t of
        TypePrimitive p ->
            Common.primitiveTypeToString p

        TypeFunction arg ret ->
            typeToString arg ++ " -> " ++ typeToString ret

        TypeTuple2 a b ->
            "( " ++ typeToString a ++ ", " ++ typeToString b ++ " )"

        TypeTuple3 a b c ->
            "( " ++ typeToString a ++ ", " ++ typeToString b ++ ", " ++ typeToString b ++ " )"


exprToString : Expr -> String
exprToString ( expr_, type_ ) =
    case expr_ of
        Literal l ->
            Common.literalToString l

        Var name ->
            name

        Binop op a b ->
            exprToString a ++ " " ++ Common.opToString op ++ " " ++ exprToString b

        Call { fn, argument } ->
            "(" ++ exprToString fn ++ " " ++ exprToString argument ++ ")"

        If { test, then_, else_ } ->
            "if " ++ exprToString test ++ " then " ++ exprToString then_ ++ " else " ++ exprToString else_

        LetIn _ ->
            Debug.todo ""

        Tuple2 a b ->
            "( " ++ exprToString a ++ ", " ++ exprToString b ++ " )"

        Tuple3 a b c ->
            "( " ++ exprToString a ++ ", " ++ exprToString b ++ ", " ++ exprToString c ++ " )"



-- Flatten


type alias Accum =
    { nextGeneratedName : Int
    , generatedFunctions : List FunctionDefinition

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


initAccum : Set Name -> Accum
initAccum globals =
    { nextGeneratedName = 0
    , generatedFunctions = []
    , collectingArguments = True
    , globals = globals
    , arguments = []
    , letInNames = Set.empty
    , inheritedNames = Dict.empty
    }


resetAccum : Accum -> Accum
resetAccum a =
    { a
        | collectingArguments = True
        , arguments = []
        , letInNames = Set.empty
        , inheritedNames = Dict.empty
    }


flattenFunction : Elm.Expr -> Accum -> ( Expr, Accum )
flattenFunction ( expr_, type_ ) acc =
    let
        andType ( e, a ) =
            ( ( e, translateType type_ ), a )
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

        Elm.Char _ ->
            Debug.todo "no chars"

        Elm.String _ ->
            Debug.todo "no strings"

        Elm.Bool b ->
            andType
                ( Common.Bool b |> Literal
                , acc
                )

        Elm.Var moduleAndName ->
            acc
                |> addToInherited (Common.moduleAndNameToName moduleAndName) (translateType type_)

        Elm.Argument name ->
            acc
                |> addToInherited name (translateType type_)

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

        Elm.Cons _ _ ->
            Debug.todo "no lists"

        Elm.Lambda { argument, body } ->
            let
                argumentType =
                    case type_ of
                        ElmT.Function a r ->
                            translateType a

                        _ ->
                            Debug.todo "shouldn't happen"

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
                    --
                    -- TODO rework the accumulators so that we just create a new type and insert the
                    -- "parent accumulator" fields as a single attribute
                    --
                    ( functionBody, lambdaAcc ) =
                        { acc
                            | arguments = [ argumentAndType ]
                            , letInNames = Set.empty
                            , inheritedNames = Dict.empty
                            , collectingArguments = True
                        }
                            |> flattenFunction body

                    additionalArguments : List ( Name, Type )
                    additionalArguments =
                        lambdaAcc.inheritedNames
                            |> Dict.toList
                            |> List.sortBy Tuple.first

                    -- add all inherited names as new function arguments
                    functionArguments : List ( Name, Type )
                    functionArguments =
                        additionalArguments ++ List.reverse lambdaAcc.arguments

                    functionName : Name
                    functionName =
                        Common.generateFunctionName lambdaAcc.nextGeneratedName

                    newFunction : Common.FunctionDefinition Type Expr
                    newFunction =
                        { name = functionName
                        , args = functionArguments
                        , expr = functionBody
                        }

                    newAcc : Accum
                    newAcc =
                        { acc
                            | nextGeneratedName = lambdaAcc.nextGeneratedName + 1
                            , generatedFunctions = newFunction :: lambdaAcc.generatedFunctions
                        }

                    -- add new arguments to type
                    functionType : Type
                    functionType =
                        List.foldl (\( argName, argType ) funType -> TypeFunction argType funType) (translateType type_) additionalArguments

                    {-
                       `theFunction` --> `theFunction arg1 arg2 ...`
                    -}
                    addArgumentToCall : ( String, Type ) -> Expr -> Expr
                    addArgumentToCall ( argName, argType ) ( fnExpr, fnType ) =
                        ( Call
                            { fn = ( fnExpr, fnType )
                            , argument = ( Var argName, argType )
                            }
                        , case fnType of
                            TypeFunction arg value ->
                                value

                            _ ->
                                Debug.todo "this should not happen"
                        )

                    -- add new arguments to call
                    callExpr =
                        List.foldl addArgumentToCall ( Var functionName, functionType ) additionalArguments

                    -- debug stuff
                    {-
                       breakDownCall ( e, t ) a =
                           case e of
                               Call stuff ->
                                   stuff.fn :: breakDownCall stuff.fn a

                               _ ->
                                   a

                       q =
                           breakDownCall callExpr []
                               |> List.map (\( e, t ) -> exprToString ( e, t ) ++ " : " ++ typeToString t |> Debug.log functionName)
                    -}
                in
                ( callExpr
                , newAcc
                )

        Elm.Call { fn, argument } ->
            let
                acc0 =
                    { acc | collectingArguments = False }

                ( aExpr, acc1 ) =
                    flattenFunction fn acc0

                ( bExpr, acc2 ) =
                    flattenFunction argument acc1
            in
            andType
                ( Call { fn = aExpr, argument = bExpr }
                , acc2
                )

        Elm.If { test, then_, else_ } ->
            let
                acc0 =
                    { acc | collectingArguments = False }

                ( testExpr, acc1 ) =
                    flattenFunction test acc0

                ( thenExpr, acc2 ) =
                    flattenFunction then_ acc1

                ( elseExpr, acc3 ) =
                    flattenFunction else_ acc2
            in
            andType
                ( If { test = testExpr, then_ = thenExpr, else_ = elseExpr }
                , acc3
                )

        Elm.Let { bindings, body } ->
            Debug.todo "todo let..in"

        Elm.List _ ->
            Debug.todo "no lists"

        Elm.Unit ->
            andType
                ( Literal Common.Unit
                , acc
                )

        Elm.Tuple a b ->
            let
                acc0 =
                    { acc | collectingArguments = False }

                ( aExpr, acc1 ) =
                    flattenFunction a acc0

                ( bExpr, acc2 ) =
                    flattenFunction b acc1
            in
            andType
                ( Tuple2 aExpr bExpr
                , acc2
                )

        Elm.Tuple3 a b c ->
            Debug.todo "(,,)"

        Elm.Record _ ->
            Debug.todo "not implemented"


addToInherited : Name -> Type -> Accum -> ( Expr, Accum )
addToInherited name type_ acc =
    let
        isDeclaredWithin =
            Set.member name acc.letInNames || List.member ( name, type_ ) acc.arguments

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


translateType : ElmT.Type -> Type
translateType elmType =
    case elmType of
        ElmT.Var a ->
            TypePrimitive Common.TypeUnit

        --Debug.todo "type variables should be resolved in a previous step"
        ElmT.Function argument return ->
            TypeFunction (translateType argument) (translateType return)

        ElmT.Int ->
            TypePrimitive Common.TypeInt

        ElmT.Float ->
            TypePrimitive Common.TypeFloat

        ElmT.Char ->
            Debug.todo "Char not supported"

        ElmT.String ->
            Debug.todo "String not supported"

        ElmT.Bool ->
            TypePrimitive Common.TypeBool

        ElmT.List _ ->
            Debug.todo "List not supported"

        ElmT.Unit ->
            TypePrimitive Common.TypeUnit

        ElmT.Tuple a b ->
            TypeTuple2 (translateType a) (translateType b)

        ElmT.Tuple3 a b c ->
            TypeTuple3 (translateType a) (translateType b) (translateType c)

        ElmT.UserDefinedType { module_, name } _ ->
            Debug.todo "not implemented"

        ElmT.Record _ ->
            Debug.todo "not implemented"
