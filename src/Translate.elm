module Translate exposing (..)

import Dict exposing (Dict)
import Elm.AST.Typed.Unwrapped as Elm
import Elm.Data.Declaration
import Elm.Data.Exposing
import Elm.Data.Module
import Elm.Data.Type as Type
import GLSL.AST as GLSL


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
---- Program Accumulator
----


type alias ProgramAcc =
    { declarations : List GLSL.Declaration
    , nextAutoName : Int

    -- TODO struct declarations
    }


initProgramAccumulator : ProgramAcc
initProgramAccumulator =
    { declarations = []
    , nextAutoName = 0
    }


newAutoName : { isFunction : Bool } -> ProgramAcc -> ( ProgramAcc, GLSL.Name )
newAutoName { isFunction } parentProgAccu =
    let
        prefix =
            if isFunction then
                "F"

            else
                "V"

        name =
            prefix ++ String.fromInt parentProgAccu.nextAutoName
    in
    ( { parentProgAccu | nextAutoName = parentProgAccu.nextAutoName + 1 }
    , name
    )


addDeclaration : GLSL.Declaration -> ProgramAcc -> ProgramAcc
addDeclaration d b =
    { b | declarations = d :: b.declarations }



----
---- Function Accumulator
----


type alias FunAcc =
    { parentProgAccu : ProgramAcc
    , argTypeByName : Dict GLSL.Name GLSL.Type
    , statements : List GLSL.Statement
    }


type alias CurliesAcc =
    { parentFunctionAcc : FunAcc
    , statements : List GLSL.Statement
    }



initFunctionAccumulator : ProgramAcc -> FunAcc
initFunctionAccumulator parentProgAccu =
    { parentProgAccu = parentProgAccu
    , statements = []
    , argTypeByName = Dict.empty
    }


addStatement : GLSL.Statement -> FunAcc -> FunAcc
addStatement statement accum =
    { accum | statements = statement :: accum.statements }


addAutoVariable : GLSL.Type -> FunAcc -> ( GLSL.Name, FunAcc )
addAutoVariable type_ fa =
    let
        ( parentProgAccu, name ) =
            newAutoName { isFunction = False } fa.parentProgAccu

        statement =
            GLSL.StatementDeclaration
                { type_ = type_
                , name = name
                , body = GLSL.DeclarationVariable { maybeInit = Nothing }
                }
    in
    ( name
    , { fa
        | parentProgAccu = parentProgAccu
        , statements = statement :: fa.statements
      }
    )



----
---- Tuple
----


type alias FunAccMonad a =
    ( a, FunAcc )


chain : (FunAcc -> FunAccMonad new) -> FunAccMonad old -> FunAccMonad ( old, new )
chain f ( old, oldAccum ) =
    let
        ( new, newAccum ) =
            f oldAccum
    in
    ( ( old, new ), newAccum )


useAndChain : (old -> FunAcc -> FunAccMonad new) -> FunAccMonad old -> FunAccMonad ( old, new )
useAndChain f ( old, oldAccum ) =
    chain (f old) ( old, oldAccum )


andThen : (a -> FunAcc -> FunAccMonad b) -> FunAccMonad a -> FunAccMonad b
andThen f ( a, accum ) =
    f a accum


andThen2 : (a -> b -> FunAcc -> FunAccMonad c) -> FunAccMonad ( a, b ) -> FunAccMonad c
andThen2 f ( ( a, b ), accum ) =
    f a b accum


andThen3 : (a -> b -> c -> FunAcc -> FunAccMonad d) -> FunAccMonad ( ( a, b ), c ) -> FunAccMonad d
andThen3 f ( ( ( a, b ), c ), accum ) =
    f a b c accum


andThen4 : (a -> b -> c -> d -> FunAcc -> FunAccMonad e) -> FunAccMonad ( ( ( a, b ), c ), d ) -> FunAccMonad e
andThen4 f ( ( ( ( a, b ), c ), d ), accum ) =
    f a b c d accum


andThen5 : (a -> b -> c -> d -> e -> FunAcc -> FunAccMonad f) -> FunAccMonad ( ( ( ( a, b ), c ), d ), e ) -> FunAccMonad f
andThen5 f ( ( ( ( ( a, b ), c ), d ), e ), accum ) =
    f a b c d e accum



---
--- Translate Type
---


translateType : Type.Type -> FunAcc -> ( GLSL.Type, FunAcc )
translateType elmType state =
    ( GLSL.Int, state )



--
-- Translate Expression
--


translateExpression : List GLSL.TypeAndName -> Elm.Expr -> FunAcc -> ( { args : List GLSL.TypeAndName, expr : GLSL.Expr, type_ : GLSL.Type }, FunAcc )
translateExpression functionArgs ( expr_, elmType ) accum =
    case expr_ of
        Elm.Int n ->
            ( { args = functionArgs
              , expr = GLSL.LiteralInt n
              , type_ = GLSL.Int
              }
            , accum
            )

        Elm.Lambda { argument, body } ->
            case elmType |> uncurryType |> List.head of
                Nothing ->
                    Debug.todo "This should not happen?"

                Just argElmType ->
                    accum
                        |> translateType argElmType
                        |> andThen
                            (\glslType acc ->
                                { acc | argTypeByName = Dict.insert argument glslType acc.argTypeByName }
                                    |> translateExpression (( glslType, argument ) :: functionArgs) body
                            )

        Elm.If elmArgs ->
            case uncurryType elmType of
                [ nonFunctionType ] ->
                    accum
                        |> translateType nonFunctionType
                        |> useAndChain addAutoVariable
                        |> chain (translateExpression [] elmArgs.test)
                        |> chain (translateExpression [] elmArgs.then_)
                        |> chain (translateExpression [] elmArgs.else_)
                        |> andThen5
                            (\glslType autoVarName test then_ else_ newAccum ->
                                ( { args = functionArgs
                                  , expr = GLSL.Variable autoVarName
                                  , type_ = glslType
                                  }
                                , newAccum
                                    |> addStatement
                                        (GLSL.If
                                            { test = test.expr
                                            , then_ = [ GLSL.Assign autoVarName then_.expr ]
                                            , else_ = [ GLSL.Assign autoVarName else_.expr ]
                                            }
                                        )
                                )
                            )

                functionType ->
                    -- TODO use a closure?
                    Debug.todo "I don't know what to do in this case"

        Elm.Argument varName ->
            case Dict.get varName accum.argTypeByName of
                Nothing ->
                    Debug.todo "this is not supposed to happen 24543"

                Just glslType ->
                    -- TODO probably need to run some magic for attributes/veryings/uniforms
                    ( { args = functionArgs
                      , expr = GLSL.Argument varName
                      , type_ = glslType
                      }
                    , accum
                    )

        _ ->
            Debug.todo (Debug.toString expr_)


translateDeclaration : Elm.Data.Declaration.Declaration Elm.Expr -> ProgramAcc -> ProgramAcc
translateDeclaration elmDeclaration oldProgAccu =
    case elmDeclaration.body of
        Elm.Data.Declaration.Value elmExpr ->
            let
                ( { args, expr, type_ }, functionAccumulator ) =
                    translateExpression [] elmExpr (initFunctionAccumulator oldProgAccu)

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
                                    functionAccumulator.statements
                                        |> (::) (GLSL.Return expr)
                                        |> List.reverse
                                }
                    }
            in
            functionAccumulator.parentProgAccu
                |> addDeclaration targetDeclaration

        _ ->
            Debug.todo "not implemented"