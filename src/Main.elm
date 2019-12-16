module Main exposing (..)

import Browser
import ElmToGLSL
import Html exposing (..)
import Html.Attributes exposing (class, classList)
import Html.Events


view : Model -> Html Msg
view model =
    div
        []
        [ div
            [ class "flex-row" ]
--             [ textarea
--                 [ Html.Events.onInput OnInput ]
--                 [ text model ]
--             [ case ElmToGLSL.translateExpression ElmToGLSL.testElmAst of
--                 Err blah ->
--                     div
--                         []
--                         [ text blah ]
-- 
--                 Ok stuff ->
--                     div
--                         []
--                         [ text (Debug.toString stuff) ]
--             ]
            [   ElmToGLSL.initFunctionAccumulator ElmToGLSL.initBlockAccumulator
                  |> ElmToGLSL.translateExpression [] ElmToGLSL.testExpression
                  |> Debug.toString
                  |> text
                  |> List.singleton
                  |> div []
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
        { init = "Whatever man"
        , view = view
        , update = update
        }


update : Msg -> Model -> Model
update msg model =
    case msg of
        OnInput s ->
            s
