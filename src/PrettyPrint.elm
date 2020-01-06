module PrettyPrint exposing (..)

-- Stolen from https://stackoverflow.com/a/40529664/1454980

import String


quote =
    "\""


indentChars =
    "[{("


outdentChars =
    "}])"


newLineChars =
    ","


uniqueHead =
    "##FORMAT##"


incr =
    4


toStringPretty : String -> String
toStringPretty elmAsString =
    elmAsString
        |> formatString False 0
        |> String.split uniqueHead
        |> List.map indentLine
        |> String.join "\n"


formatString : Bool -> Int -> String -> String
formatString isInQuotes indent str =
    case String.left 1 str of
        "" ->
            ""

        firstChar ->
            if isInQuotes then
                if firstChar == quote then
                    firstChar
                        ++ formatString (not isInQuotes) indent (String.dropLeft 1 str)

                else
                    firstChar
                        ++ formatString isInQuotes indent (String.dropLeft 1 str)

            else if String.contains firstChar newLineChars then
                uniqueHead
                    ++ pad indent
                    ++ firstChar
                    ++ formatString isInQuotes indent (String.dropLeft 1 str)

            else if String.contains firstChar indentChars then
                uniqueHead
                    ++ pad (indent + incr)
                    ++ firstChar
                    ++ formatString isInQuotes (indent + incr) (String.dropLeft 1 str)

            else if String.contains firstChar outdentChars then
                firstChar
                    ++ uniqueHead
                    ++ pad (indent - incr)
                    ++ formatString isInQuotes (indent - incr) (String.dropLeft 1 str)

            else if firstChar == quote then
                firstChar
                    ++ formatString (not isInQuotes) indent (String.dropLeft 1 str)

            else
                firstChar
                    ++ formatString isInQuotes indent (String.dropLeft 1 str)


pad : Int -> String
pad indent =
    indent
        |> String.fromInt
        |> String.padLeft 5 '0'


indentLine : String -> String
indentLine s =
    let
        ( indent, content ) =
            splitLine s
    in
    String.repeat indent " " ++ content


splitLine : String -> ( Int, String )
splitLine line =
    let
        indent =
            line
                |> String.left 5
                |> String.toInt
                |> Maybe.withDefault 0

        newLine =
            String.dropLeft 5 line
    in
    ( indent, newLine )
