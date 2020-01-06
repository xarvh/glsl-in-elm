module Crawl exposing (..)

import Dict exposing (Dict)
import Elm.AST.Typed.Unwrapped exposing (Expr, Expr_(..))
import Elm.Data.Binding exposing (Binding)
import Set exposing (Set)


type alias VarName =
    String


{-| -}
type alias FunctionScope =
    { arguments : List VarName
    , referencedVarNames : Set VarName
    , letInNames : Set VarName

    -- This is used to get a rough estimate of the function length
    , complexity : Float

    -- TODO Without a way to map an Expr to its NestedScope, this attr is not super useful
    , children : List NestedScope
    }


type NestedScope
    = NestedScope FunctionScope


initScope : FunctionScope
initScope =
    { arguments = []
    , referencedVarNames = Set.empty
    , letInNames = Set.empty
    , complexity = 0
    , children = []
    }


increaseComplexityBy : Float -> FunctionScope -> FunctionScope
increaseComplexityBy n scope =
    { scope | complexity = scope.complexity + n }



--


getDeclaredByFunction : FunctionScope -> Set VarName
getDeclaredByFunction scope =
    Set.empty
        |> Set.union (Set.fromList scope.arguments)
        |> Set.union scope.letInNames


{-| Find the var names that the function expects to find from the ancestors scopes
-}
getInheritedVarNames : FunctionScope -> Set VarName
getInheritedVarNames scope =
    Set.diff scope.referencedVarNames (getDeclaredByFunction scope)



--


flattenName : { module_ : String, name : String } -> VarName
flattenName { module_, name } =
    -- TODO `_` is a valid module name char, so uniqueness is not guaranteed
    -- TODO how are let..in bindings going to be referenced?
    String.replace "." "_" module_ ++ name



--


{-| When we encounter a lambda, we have two cases:

    1) The lambda is part of the same imperative function declaration:

        `lol a = \x -> a + x` => `lol a x = a + x`

        If this is the case, we just add another argument to the list

    2) something that can't be turned into an imperative function declaration:

        A tuple: `(1, 2, \x -> x * 2)`

        An argument of a function call: `Maybe.map (\x -> x * 2)`

        A let..in binding : `let m x = x * 2 in ...`

        In this case, we want to start with a clean scope accumulator

-}
crawlWithNewScope : Expr -> FunctionScope -> FunctionScope
crawlWithNewScope expr parentScope =
    let
        childScope =
            crawl expr initScope

        inherited =
            getInheritedVarNames childScope

        -- A child might expect var names that don't come directly by the parent, but by one of the parent's ancestors.
        -- These var names must become requirements for the parent as well.
        additionalForParent =
            Set.diff inherited (getDeclaredByFunction parentScope)
    in
    { parentScope
        | children = NestedScope childScope :: parentScope.children
        , referencedVarNames = Set.union additionalForParent parentScope.referencedVarNames
    }


crawl : Expr -> FunctionScope -> FunctionScope
crawl ( expr_, type_ ) scope =
    case expr_ of
        Int n ->
            scope

        Float n ->
            scope

        Char c ->
            scope

        String c ->
            scope

        Bool bool ->
            scope

        Var moduleAndName ->
            { scope | referencedVarNames = Set.insert (flattenName moduleAndName) scope.referencedVarNames }

        Argument varName ->
            -- TODO do we care to keep track of whether an argument is actually used or not?
            scope

        Plus exprA exprB ->
            scope
                |> increaseComplexityBy 1
                |> crawl exprA
                |> crawl exprB

        Cons exprA exprB ->
            scope
                |> increaseComplexityBy 1
                |> crawl exprA
                |> crawl exprB

        Lambda { argument, body } ->
            { scope | arguments = argument :: scope.arguments }
                |> crawl body

        Call { fn, argument } ->
            scope
                -- TODO Right now a function with 3 args will be counted 3 times, would be nice to count it only once
                |> increaseComplexityBy 0.5
                |> crawl fn
                |> crawlWithNewScope argument

        If { test, then_, else_ } ->
            scope
                |> increaseComplexityBy 1
                |> crawl test
                |> crawl then_
                |> crawl else_

        Let { bindings, body } ->
            bindings
                |> Dict.foldl addBinding scope
                |> crawl body

        List items ->
            Debug.todo "not supported"

        Unit ->
            scope

        Tuple exprA exprB ->
            scope
                |> increaseComplexityBy 1
                |> crawlWithNewScope exprA
                |> crawlWithNewScope exprB

        Tuple3 exprA exprB exprC ->
            scope
                |> increaseComplexityBy 1
                |> crawlWithNewScope exprA
                |> crawlWithNewScope exprB
                |> crawlWithNewScope exprC

        Record blah ->
            Debug.todo "NI"


addBinding : String -> Binding Expr -> FunctionScope -> FunctionScope
addBinding name_again { name, body } scope =
    { scope | letInNames = Set.insert name scope.letInNames }
        |> increaseComplexityBy 0.5
        |> crawlWithNewScope body
