module Main exposing (..)

import Browser
import Dict
import Elm.AST.Typed as Typed
import Elm.AST.Typed.Unwrapped
import Elm.Compiler
import Elm.Compiler.Error exposing (Error)
import Elm.Data.Declaration
import Elm.Data.Module as Module exposing (Module)
import Flatten
import GLSL.AST
import Html exposing (..)
import Html.Attributes exposing (class, classList, style)
import Html.Events
import PrettyPrint
import Set exposing (Set)
import Uncurry



-- import Translate


init =
    """module Meh exposing (..)

ooo = 9

meh = \\a b -> 3 + ooo

q = \\l -> 2

someFunction =
    \\someBool ->
        if someBool then
            \\f -> 3

        else if someBool then
            \\x -> ooo

        else
            meh 5
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

        globals =
            elmDeclarations
                |> List.map .name
                |> Set.fromList

        flattened =
            List.foldl flattenDeclaration (Flatten.initAccum globals) elmDeclarations

        flattenDeclaration { name, body } a0 =
            case body of
                Elm.Data.Declaration.Value v ->
                    let
                        ( expr, a1 ) =
                            Flatten.flattenFunction v a0

                        f =
                            { name = name
                            , args = a1.arguments
                            , expr = expr
                            }
                    in
                    { a1 | generatedFunctions = f :: a1.generatedFunctions }

                _ ->
                    Debug.todo "Bkkkka"
    in
    div
        []
        [ div
            [ class "flex-row" ]
            [ div
                []
                [ textarea
                    [ Html.Events.onInput OnInput
                    , style "min-height" "300px"
                    , style "min-width" "900px"
                    ]
                    [ text model ]
                , pre
                    []
                    [ code
                        []
                        [ flattened.generatedFunctions
                            |> List.map Flatten.functionToString
                            |> String.join "\n\n"
                            |> text
                        ]
                    ]
                ]
            , pre
                []
                [ code
                    []
                    [ []
                        --blockAccumulator.declarations
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
