module ElmToGLSL exposing (..)

import Dict exposing (Dict)
import Elm.AST.Typed.Unwrapped as Elm
import Elm.Data.Declaration
import Elm.Data.Exposing
import Elm.Data.Module
import Elm.Data.Type as Type
import GLSL.AST


testElmAst : Elm.Data.Module.Module Elm.Expr
testElmAst =
    { name = "SomeShaderModule"
    , filePath = "$path"
    , exposing_ = Elm.Data.Exposing.ExposingAll
    , imports = Dict.fromList []
    , type_ = Elm.Data.Module.PlainModule
    , declarations =
        Dict.fromList
            [ ( "floatToVec4"
              , { body =
                    Elm.Data.Declaration.Value
                        ( Elm.Lambda
                            { argument = "f"
                            , body =
                                ( Elm.Plus
                                    ( Elm.Argument "f", Type.Int )
                                    ( Elm.Int 2, Type.Int )
                                , Type.Int
                                )
                            }
                        , Type.Function Type.Int Type.Int
                        )
                , module_ = "Shader"
                , name = "floatToVec4"
                }
              )
            , ( "shader_Color"
              , { body =
                    Elm.Data.Declaration.Value
                        ( Elm.Lambda
                            { argument = "attribute_color"
                            , body =
                                ( Elm.Lambda
                                    { argument = "uniform_shade"
                                    , body =
                                        ( Elm.Lambda
                                            { argument = "varying_position"
                                            , body =
                                                ( Elm.Plus
                                                    ( Elm.Plus
                                                        ( Elm.Argument "attribute_color", Type.Int )
                                                        ( Elm.Argument "uniform_shade", Type.Int )
                                                    , Type.Int
                                                    )
                                                    ( Elm.Int 2
                                                    , Type.Int
                                                    )
                                                , Type.Int
                                                )
                                            }
                                        , Type.Function (Type.Var 10) Type.Int
                                        )
                                    }
                                , Type.Function Type.Int (Type.Function (Type.Var 10) Type.Int)
                                )
                            }
                        , Type.Function Type.Int (Type.Function Type.Int (Type.Function (Type.Var 10) Type.Int))
                        )
                , module_ = "Shader"
                , name = "shader_Color"
                }
              )
            ]
    }
