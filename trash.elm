module Main exposing (declaration, elmExprToShaderBlock, elmFunctionToGlslEmbeddedBlock, fragmentShader)


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
