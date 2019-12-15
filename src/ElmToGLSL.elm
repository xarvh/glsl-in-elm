module ElmToGLSL exposing (..)

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



{-
   elmFunctionToGlslEmbeddedBlock : String -> Elm.Data.Module.Module Elm.Expr -> Result String GLSL.EmbeddedBlock
   elmFunctionToGlslEmbeddedBlock targetName elmModule =
       case Dict.get targetName elmModule.declarations of
           Nothing ->
               Err "no target"

           Just targetDeclaration ->
               case targetDeclaration.body of
                   Elm.Data.Declaration.Value expr ->
                       fragmentShader targetName expr elmModule

                   _ ->
                       Err "target is not a declaration"


   fragmentShader : String -> Elm.Expr -> Elm.Data.Module.Module Elm.Expr -> Result String FragmentShaderBlock
   fragmentShader targetName ( body, type_ ) elmModule =
       case uncurryType type_ of
           uniforms :: varyings :: output :: [] ->
               if output /= fragmentShaderOutputType then
                   Err "output type does not match fragmentShaderOutputType"

               else
                   -- TODO get the type definitions for uniforms and varyings, ensure they are suitable records, pass them to bodyToGLSL
                   body
                       |> elmExprToShaderBlock elmModule
                       |> Result.map
                           (\embeddedBlock ->
                               { name = "glsl_" ++ targetName
                               , uniforms = uniforms
                               , varyings = varyings
                               , glsl = embeddedBlock
                               }
                           )

           anythingElse ->
               anythingElse
                   |> Debug.toString
                   |> (++) "Wrong type for a fragment shader: "
                   |> Err


   elmExprToShaderBlock : Elm.Expr_ -> Result String FragmentShaderBlock
   elmExprToShaderBlock expr_ =
       let
           mainBody =
               declaration expr_
       in
       Err "LOL"


   declaration : Elm.Expr -> Result String { body : GLSL.DeclarationBody, requiredSymbols : List String }
   declaration ( expr_, type_ ) =
       Err "LOL"

-}
----
---- STATE
----


type alias State =
    { statements : List GLSL.Statement
    , nextAutoVariable : Int
    }


stateInit : State
stateInit =
    { statements = []
    , nextAutoVariable = 0
    }


map : (a -> State -> ( b, State )) -> ( a, State ) -> ( b, State )
map f ( a, state ) =
    f a state


andMapState : (a -> ( b, State -> State )) -> ( a, State ) -> ( b, State )
andMapState f ( a, state ) =
    let
        ( b, updateState ) =
            f a
    in
    ( b, updateState state )


chain2 : (State -> ( a, State )) -> (State -> ( b, State )) -> State -> ( ( a, b ), State )
chain2 fa fb s0 =
    let
        ( a, s1 ) =
            fa s0

        ( b, s2 ) =
            fb s1
    in
    ( ( a, b ), s2 )


chain3 : (State -> ( a, State )) -> (State -> ( b, State )) -> (State -> ( c, State )) -> State -> ( ( a, b, c ), State )
chain3 fa fb fc s0 =
    let
        ( a, s1 ) =
            fa s0

        ( b, s2 ) =
            fb s1

        ( c, s3 ) =
            fc s2
    in
    ( ( a, b, c ), s3 )



--


addStatement : GLSL.Statement -> State -> State
addStatement statement state =
    { state | statements = statement :: state.statements }


addAutoVariable : GLSL.Type -> State -> ( GLSL.Name, State )
addAutoVariable type_ s =
    let
        variableIndex =
            s.nextAutoVariable

        variableName =
            "A" ++ String.fromInt variableIndex

        variableDeclaration =
            GLSL.StatementDeclaration
                { type_ = type_
                , name = variableName
                , body = GLSL.DeclarationVariable { maybeInit = Nothing }
                }
    in
    ( variableName
    , { s
        | statements = variableDeclaration :: s.statements
        , nextAutoVariable = variableIndex + 1
      }
    )



---


translateType : Type.Type -> State -> ( GLSL.Type, State )
translateType elmType state =
    ( GLSL.Int, state )


type alias GlslArg =
    { type_ : GLSL.Type, name : GLSL.Name }


translateExpression : List GlslArg -> Elm.Expr -> State -> ( { args : List GlslArg, expr : GLSL.Expr }, State )
translateExpression functionArgs ( expr_, elmType ) state =
    case expr_ of
        Elm.Int n ->
            ( { args = functionArgs
              , expr = GLSL.LiteralInt n
              }
            , state
            )

        Elm.Lambda { argument, body } ->
            case elmType |> uncurryType |> List.head of
                Nothing ->
                    Debug.todo "This should not happen?"

                Just argElmType ->
                    state
                        |> translateType argElmType
                        |> map (\glslType -> translateExpression (( glslType, argument ) :: functionArgs) body)

        Elm.If elmArgs ->
            case uncurryType elmType of
                [ nonFunctionType ] ->
                    state
                        |> chain2
                            (translateType nonFunctionType >> map addAutoVariable)
                            (chain3
                                (translateExpression [] elmArgs.test)
                                (translateExpression [] elmArgs.then_)
                                (translateExpression [] elmArgs.else_)
                            )
                        |> andMapState
                            (\( varName, ( test, then_, else_ ) ) ->
                                ( GLSL.Variable varName
                                , addStatement
                                    (GLSL.If
                                        { test = test
                                        , then_ = GLSL.Assign varName then_
                                        , else_ = Just <| GLSL.Assign varName else_
                                        }
                                    )
                                )
                            )

                functionType ->
                    Debug.todo "I don't know what to do in this case"

        _ ->
            Debug.todo (Debug.toString expr_)
