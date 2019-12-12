module ElmToGLSL exposing (..)

import Dict exposing (Dict)
import Elm.AST.Typed.Unwrapped as Elm
import Elm.Data.Declaration
import Elm.Data.Exposing
import Elm.Data.Module
import Elm.Data.Type as Type
import GLSL.AST


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
    Type.UserDefinedType
        { module_ = ""
        , name = "FragmentShaderOutput"
        }
        []


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
                                        ( Elm.Int 3
                                        , Type.Int
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
