module Main exposing (..)

import Browser
import Dict
import Elm.AST.Typed as Typed
import Elm.AST.Typed.Unwrapped exposing (Expr)
import Elm.Compiler
import Elm.Compiler.Error exposing (Error)
import Elm.Data.Declaration as Declaration exposing (Declaration)
import Elm.Data.FileContents exposing (FileContents)
import Elm.Data.Module as Module exposing (Module)
import Elm.Data.Type as Type exposing (Type)
import ElmToGLSL
import Html exposing (..)
import Html.Attributes exposing (class, classList)
import Html.Events


init =
    """

floatToVec4 = \\f -> f + 2

shader_Color = \\attribute_color uniform_shade varying_position ->
  attribute_color + uniform_shade + 2






      """


-- elmToGlSl : { filePath : String, sourceCode : String } -> String
elmToGlSl file =
    file
        |> Elm.Compiler.parseModule
        |> Result.andThen Elm.Compiler.desugarOnlyModule
        |> Result.andThen Elm.Compiler.inferModule
        |> Result.map (Elm.Compiler.optimizeModule >> Module.map Typed.unwrap)


view : Model -> Html Msg
view model =
    div
        []
        [ div
            [ class "flex-row" ]
            [ textarea
                [ Html.Events.onInput OnInput ]
                [ text model ]
            , case elmToGlSl { filePath = "$path", sourceCode = "module Shader exposing (..)" ++ model } of
                Err blah ->
                    div
                        []
                        [ text (Debug.toString blah) ]

                Ok stuff ->
                    div
                        []
                        [ text (Debug.toString stuff) ]
            ]
        , node "style" [] [ text css ]
        ]


viewDeclaration declaration =
    li
        []
        [ div
            []
            [ text declaration.name ]
        , div
            []
            [ Debug.toString declaration.body |> text ]
        ]


css : String
css =
    """
.flex-row { display: flex; }
.flex-row > * { width: 50%; padding: 1em; }

  """



----


type alias Model =
    String


type Msg
    = OnInput String


main =
    Browser.sandbox
        { init = init
        , view = view
        , update = update
        }


update : Msg -> Model -> Model
update msg model =
    case msg of
        OnInput s ->
            s
