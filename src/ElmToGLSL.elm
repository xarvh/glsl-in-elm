module ElmToGLSL exposing (..)

import Dict exposing (Dict)
import Elm.AST.Typed.Unwrapped as Elm
import Elm.Data.Declaration
import Elm.Data.Exposing
import Elm.Data.Module
import Elm.Data.Type as Type
import GLSL.AST


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


elmToGLSL : String -> Elm.Data.Module.Module Elm.Expr -> Result String GLSL.AST.EmbeddedBlock
elmToGLSL targetName elmModule =
    case Dict.get targetName elmModule.declarations of
        Nothing ->
            Err "no target"

        Just targetDeclaration ->
            case targetDeclaration.body of
                Elm.Data.Declaration.Value expr ->
                    fragmentShaderElmToGLSL expr elmModule

                _ ->
                    Err "target is not a declaration"


fragmentShaderElmToGLSL : Elm.Expr -> Elm.Data.Module.Module Elm.Expr -> Result String GLSL.AST.EmbeddedBlock
fragmentShaderElmToGLSL expr elmModule =
    expr
        |> Tuple.second
        |> uncurryType
        |> Debug.toString
        |> Err


uncurryType : Type.Type -> List Type.Type
uncurryType type_ =
    case type_ of
        Type.Function inType outType ->
            inType :: uncurryType outType

        _ ->
            [ type_ ]
