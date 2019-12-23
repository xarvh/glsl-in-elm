module Main exposing (..)

import Browser
import Dict
import Elm.AST.Typed as Typed
import Elm.AST.Typed.Unwrapped
import Elm.Compiler
import Elm.Compiler.Error exposing (Error)
import Elm.Data.Module as Module exposing (Module)
import Translate
import GLSL.AST
import Html exposing (..)
import Html.Attributes exposing (class, classList)
import Html.Events


init =
  """module Meh exposing (..)

meh = \\a b -> 3

someFunction = \\someBool -> if someBool then 1 else if someBool then 5 else 6
  """




elmToGlsl : String -> Result Error (Module Elm.AST.Typed.Unwrapped.Expr)
elmToGlsl content =
    { filePath = "theFilepath", sourceCode = content }
        |> Elm.Compiler.parseModule
        |> Result.andThen Elm.Compiler.desugarOnlyModule
        |> Result.andThen Elm.Compiler.inferModule
        |> Result.map Elm.Compiler.optimizeModule
        |> Result.map (Module.map Typed.unwrap)


view : Model -> Html Msg
view model =
    let
        result =
            elmToGlsl model

        elmDeclarations =
            result
                |> Result.map (.declarations >> Dict.values)
                |> Result.withDefault []

        blockAccumulator =
            --ElmToGLSL.initBlockAccumulator
            List.foldl Translate.translateDeclaration Translate.translateDeclarationInit elmDeclarations
    in
    div
        []
        [ div
            [ class "flex-row" ]
            [ textarea
                [ Html.Events.onInput OnInput ]
                [ text model ]
            , pre
                []
                [ code
                    []
                    [ blockAccumulator.declarations
                        |> List.map GLSL.AST.declarationToString
                        |> String.join "\n\n"
                        |> text
                    ]
                ]
            ]
        , div
            [ class "flex-row" ]
            [ case result of
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
    case Debug.log "" msg of
        OnInput s ->
            s
