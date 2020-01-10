module Translate exposing (..)

import Dict exposing (Dict)
import Dict.Extra
import Elm.AST.Typed.Unwrapped as Elm
import Elm.Data.Declaration
import Elm.Data.Exposing
import Elm.Data.Module
import Elm.Data.Type as Type
import GLSL.AST as GLSL
import List.Extra


uncurryType : Type.Type -> List Type.Type
uncurryType type_ =
    case type_ of
        Type.Function inType outType ->
            inType :: uncurryType outType

        _ ->
            [ type_ ]



--


type alias FragmentShaderBlock =
    { name : String
    , uniforms : Type.Type
    , varyings : Type.Type
    , glsl : GLSL.EmbeddedBlock
    }


vec4Type : Type.Type
vec4Type =
    Type.UserDefinedType
        { module_ = ""
        , name = "Vec4"
        }
        []


uniformsType : Type.Type
uniformsType =
    Type.UserDefinedType
        { module_ = ""
        , name = "Uniforms"
        }
        []


varyingsType : Type.Type
varyingsType =
    Type.UserDefinedType
        { module_ = ""
        , name = "Varyings"
        }
        []


fragmentShaderOutputType : Type.Type
fragmentShaderOutputType =
    Type.Tuple3 Type.Float Type.Float Type.Float


testExpression : Elm.Expr
testExpression =
    ( Elm.Lambda
        { argument = "uniforms"
        , body =
            ( Elm.Lambda
                { argument = "varyings"
                , body = ( Elm.Int 1, Type.Int )
                }
            , Type.Function varyingsType fragmentShaderOutputType
            )
        }
    , Type.Function uniformsType (Type.Function varyingsType fragmentShaderOutputType)
    )


testDeclaration : Elm.Data.Declaration.Declaration Elm.Expr
testDeclaration =
    { module_ = "TheModule"
    , name = "zeFunction"
    , body = Elm.Data.Declaration.Value testExpression
    }


testElmAst : Elm.Data.Module.Module Elm.Expr
testElmAst =
    { name = "SomeShaderModule"
    , filePath = "$path"
    , exposing_ = Elm.Data.Exposing.ExposingAll
    , imports = Dict.fromList []
    , type_ = Elm.Data.Module.PlainModule
    , declarations =
        Dict.fromList
            [ ( "someFragmentShader"
              , { body =
                    Elm.Data.Declaration.Value
                        ( Elm.Lambda
                            { argument = "uniforms"
                            , body =
                                ( Elm.Lambda
                                    { argument = "varyings"
                                    , body =
                                        -- red
                                        ( Elm.Tuple3
                                            ( Elm.Float 1, Type.Float )
                                            ( Elm.Float 0, Type.Float )
                                            ( Elm.Float 0, Type.Float )
                                        , fragmentShaderOutputType
                                        )
                                    }
                                , Type.Function varyingsType fragmentShaderOutputType
                                )
                            }
                        , Type.Function uniformsType (Type.Function varyingsType fragmentShaderOutputType)
                        )
                , module_ = "SomeShaderModule"
                , name = "someFragmentShader"
                }
              )
            ]
    }



----
---- Translation State
----


type alias TransM payload =
    ( payload, TranslateExpressionState )


chain : (TranslateExpressionState -> TransM new) -> TransM old -> TransM ( old, new )
chain f ( old, oldAccum ) =
    let
        ( new, newAccum ) =
            f oldAccum
    in
    ( ( old, new ), newAccum )


useAndChain : (old -> TranslateExpressionState -> TransM new) -> TransM old -> TransM ( old, new )
useAndChain f ( old, oldAccum ) =
    chain (f old) ( old, oldAccum )


andThen : (a -> TranslateExpressionState -> TransM b) -> TransM a -> TransM b
andThen f ( a, accum ) =
    f a accum


andThen2 : (a -> b -> TranslateExpressionState -> TransM c) -> TransM ( a, b ) -> TransM c
andThen2 f ( ( a, b ), accum ) =
    f a b accum


andThen3 : (a -> b -> c -> TranslateExpressionState -> TransM d) -> TransM ( ( a, b ), c ) -> TransM d
andThen3 f ( ( ( a, b ), c ), accum ) =
    f a b c accum


andThen4 : (a -> b -> c -> d -> TranslateExpressionState -> TransM e) -> TransM ( ( ( a, b ), c ), d ) -> TransM e
andThen4 f ( ( ( ( a, b ), c ), d ), accum ) =
    f a b c d accum


andThen5 : (a -> b -> c -> d -> e -> TranslateExpressionState -> TransM f) -> TransM ( ( ( ( a, b ), c ), d ), e ) -> TransM f
andThen5 f ( ( ( ( ( a, b ), c ), d ), e ), accum ) =
    f a b c d e accum


map : (a -> b) -> TransM a -> TransM b
map f ( a, accum ) =
    ( f a, accum )


map2 : (a -> b -> c) -> TransM ( a, b ) -> TransM c
map2 f ( ( a, b ), accum ) =
    ( f a b, accum )


map5 : (a -> b -> c -> d -> e -> f) -> TransM ( ( ( ( a, b ), c ), d ), e ) -> TransM f
map5 f ( ( ( ( ( a, b ), c ), d ), e ), accum ) =
    ( f a b c d e, accum )


compose : (a -> TranslateExpressionState -> TransM b) -> List a -> TranslateExpressionState -> TransM (List b)
compose f ls state =
    let
        fold a ( bs, s ) =
            f a s
                |> Tuple.mapFirst (\b -> b :: bs)
    in
    List.foldr fold ( [], state ) ls



--
-- Translate Expression
--


type alias TranslateExpressionState =
    { nextAutoName : Int
    , auxVar : Dict GLSL.Name GLSL.Type
    , args : List ( GLSL.Type, GLSL.Name )
    , autoStructs : Dict GLSL.Name (List GLSL.Type)
    , calledFunctions : List SymbolReference
    }


type alias TranslateExpressionOut =
    { expr : GLSL.Expr
    , type_ : GLSL.Type
    , auxStatements : List GLSL.Statement
    }


addAutoVariable : GLSL.Type -> TranslateExpressionState -> TransM GLSL.Name
addAutoVariable type_ state =
    let
        name =
            "V" ++ String.fromInt state.nextAutoName
    in
    ( name
    , { state
        | nextAutoName = state.nextAutoName + 1
        , auxVar = Dict.insert name type_ state.auxVar
      }
    )


addAutoStruct : List GLSL.Type -> TranslateExpressionState -> TransM GLSL.Name
addAutoStruct types state =
    -- TODO faster pre-existing struct lookup
    -- TODO types should be non-ordered? --> sort types!
    case Dict.Extra.find (\n t -> t == types) state.autoStructs of
        Just ( n, t ) ->
            ( n, state )

        Nothing ->
            let
                name =
                    "struct" ++ String.fromInt state.nextAutoName
            in
            ( name
            , { state
                | nextAutoName = state.nextAutoName + 1
                , autoStructs = Dict.insert name types state.autoStructs
              }
            )


translateExpression : Elm.Expr -> TranslateExpressionState -> TransM TranslateExpressionOut
translateExpression ( expr_, elmType ) acc =
    case expr_ of
        Elm.Int n ->
            ( { expr = GLSL.LiteralInt n
              , type_ = GLSL.Int
              , auxStatements = []
              }
            , acc
            )

        Elm.Call { fn, argument } ->
            case maybeDirectCallName ( expr_, elmType ) of
                Just ( elmSymbolReference, elmArgs ) ->
                    -- simple function call
                    acc
                        |> translateSymbolReference elmSymbolReference
                        |> chain (compose translateExpression elmArgs)
                        |> map2
                            (\glslFunName glslArgs ->
                                { expr = GLSL.FunctionCall glslFunName (List.map .expr glslArgs)

                                -- TODO actually put a value or dump the whole type_ attribute
                                , type_ = GLSL.Int
                                , auxStatements = List.concatMap .auxStatements glslArgs
                                }
                            )

                Nothing ->
                    -- closure
                    Debug.todo "closures are not implemented"

        Elm.Lambda { argument, body } ->
            case elmType |> uncurryType |> List.head of
                Nothing ->
                    Debug.todo "This should not happen?"

                Just argElmType ->
                    acc
                        |> translateType argElmType []
                        |> andThen
                            (\glslType newAcc ->
                                { newAcc | args = ( glslType, argument ) :: newAcc.args }
                                    |> translateExpression body
                            )

        Elm.If elmArgs ->
            case uncurryType elmType of
                [ nonFunctionType ] ->
                    acc
                        |> translateType nonFunctionType []
                        |> useAndChain addAutoVariable
                        |> chain (translateExpression elmArgs.test)
                        |> chain (translateExpression elmArgs.then_)
                        |> chain (translateExpression elmArgs.else_)
                        |> map5
                            (\glslType autoVarName test then_ else_ ->
                                { expr = GLSL.Variable autoVarName
                                , type_ = glslType
                                , auxStatements =
                                    GLSL.If
                                        { test = test.expr
                                        , then_ = GLSL.Assign autoVarName then_.expr :: then_.auxStatements |> List.reverse
                                        , else_ = GLSL.Assign autoVarName else_.expr :: else_.auxStatements |> List.reverse
                                        }
                                        :: test.auxStatements
                                        |> List.reverse
                                }
                            )

                functionType ->
                    -- TODO use a closure?
                    Debug.todo "I don't know what to do in this case"

        Elm.Argument varName ->
            case List.Extra.find (\( type_, name ) -> name == varName) acc.args of
                Nothing ->
                    Debug.todo "this is not supposed to happen 24543"

                Just ( glslType, name ) ->
                    -- TODO probably need to run some magic for attributes/varyings/uniforms
                    ( { expr = GLSL.Argument varName
                      , type_ = glslType
                      , auxStatements = []
                      }
                    , acc
                    )

        _ ->
            Debug.todo (Debug.toString expr_)


type alias SymbolReference =
    { module_ : String, name : String }


maybeDirectCallName : Elm.Expr -> Maybe ( SymbolReference, List Elm.Expr )
maybeDirectCallName ( expr_, elmType ) =
    case expr_ of
        Elm.Var symbolReference ->
            Just ( symbolReference, [] )

        Elm.Call { fn, argument } ->
            maybeDirectCallName fn |> Maybe.map (Tuple.mapSecond <| (::) argument)

        _ ->
            Nothing


translateSymbolReference : SymbolReference -> TranslateExpressionState -> TransM String
translateSymbolReference symbolReference state =
    ( symbolReferenceToGlslName symbolReference
    , { state | calledFunctions = symbolReference :: state.calledFunctions }
    )


symbolReferenceToGlslName : SymbolReference -> GLSL.Name
symbolReferenceToGlslName ref =
    String.replace "." "_" ref.module_ ++ "_" ++ ref.name



---
--- Translate Type
---


translateType : Type.Type -> List Type.Type -> TranslateExpressionState -> ( GLSL.Type, TranslateExpressionState )
translateType elmType parentTypes state =
    case elmType of
        Type.Int ->
            ( GLSL.Int
            , state
            )

        Type.Float ->
            ( GLSL.Float
            , state
            )

        Type.Bool ->
            ( GLSL.Bool
            , state
            )

        Type.Tuple elmA elmB ->
            state
                |> translateType elmA (elmType :: parentTypes)
                |> chain (translateType elmB (elmType :: parentTypes))
                |> andThen2 (\glslA glslB -> addAutoStruct [ glslA, glslB ])
                |> map (\name -> GLSL.Struct { name = name })

        Type.Tuple3 elmA elmB elmC ->
            state
                |> translateType elmA (elmType :: parentTypes)
                |> chain (translateType elmB (elmType :: parentTypes))
                |> chain (translateType elmC (elmType :: parentTypes))
                |> andThen3 (\glslA glslB glslC -> addAutoStruct [ glslA, glslB, glslC ])
                |> map (\name -> GLSL.Struct { name = name })

        Type.Var _ ->
            -- This can happen if a variable or argument is not really used, so we should be able to set it to whatever
            ( GLSL.Int
            , state
            )

        Type.UserDefinedType { module_, name } args ->
            Debug.todo "not implemented"

        _ ->
            Debug.todo <| "type " ++ Debug.toString elmType ++ " cannot be used in GLSL"



--
-- Translate Declaration
--


type alias TranslateDeclarationState =
    { nextAutoName : Int
    , declarations : List GLSL.Declaration
    , calledFunctions : List SymbolReference
    }


translateDeclarationInit : TranslateDeclarationState
translateDeclarationInit =
    { nextAutoName = 0
    , declarations = []
    , calledFunctions = []
    }


translateDeclaration : Elm.Data.Declaration.Declaration Elm.Expr -> TranslateDeclarationState -> TranslateDeclarationState
translateDeclaration elmDeclaration state =
    case elmDeclaration.body of
        Elm.Data.Declaration.Value elmExpr ->
            let
                ( { expr, type_, auxStatements }, { nextAutoName, auxVar, args } ) =
                    translateExpression elmExpr
                        { nextAutoName = state.nextAutoName
                        , auxVar = Dict.empty
                        , args = []
                        , autoStructs = Dict.empty
                        , calledFunctions = state.calledFunctions
                        }

                varDeclarations =
                    auxVar
                        |> Dict.toList
                        |> List.sortBy Tuple.first
                        |> List.map
                            (\( n, t ) ->
                                GLSL.StatementDeclaration
                                    { type_ = t
                                    , name = n
                                    , body = GLSL.DeclarationVariable { maybeInit = Nothing }
                                    }
                            )

                targetDeclaration =
                    { type_ = type_
                    , name = elmDeclaration.name
                    , body =
                        if args == [] then
                            GLSL.DeclarationVariable { maybeInit = Just expr }

                        else
                            GLSL.DeclarationFunction
                                { args = List.reverse args
                                , statements =
                                    varDeclarations ++ (GLSL.Return expr :: auxStatements |> List.reverse)
                                }
                    }
            in
            { state
                | nextAutoName = nextAutoName
                , declarations = targetDeclaration :: state.declarations
                , calledFunctions = state.calledFunctions
            }

        _ ->
            Debug.todo "not implemented"
