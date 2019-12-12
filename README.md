Proposal: transpiling Elm code to GLSL
======================================

The main problem that this proposal wants to solve is the inability to reuse code
when writing shaders: if I declare a function in a shader, the only way I can reuse it
in a different shader is to cut and paste the function code.

This prevents us from writing generic code that can be reused and shared in libraries.


The core idea is to use a subset of the Elm language to express shaders, so that while
not all Elm code is valid shader code, a shader can be entirely written in Elm and
*all shader code is valid Elm code*.

The main language features excluded from the subset would be functional recursion and
recursive custom types such as `List`.


Example
-------

```elm
module SomeShader exposing (..)

-- Elm.GLSL is re-exposing the VecX, Mat4 types from elm-explorations/linear-algebra,
-- and implementing the GLSL built-in functions on top of them.
import Elm.GLSL exposing (Vec2, Vec3, Vec4, Mat4, vec2to4, vec3to4)


type alias Attributes =
    { position : Vec2 }


type alias Uniforms =
    { entityToCamera : Mat4
    , dimensions : Vec2
    , fill : Vec3
    , stroke : Vec3
    , strokeWidth : Float
    , opacity : Float
    }


type alias Varying =
    { localPosition : Vec2 }


quad : Attributes -> Uniforms -> { varyings : Varying, gl_Position : Vec4 }
quad a u =
    let
        localPosition =
            (u.dimensions + u.strokeWidth * 2.0) * a.position
    in
    { varyings =
        { localPosition = localPosition }
    , gl_Position =
        u.entityToCamera * vec2to4 localPosition 0 1
    }


quadShader : VertexShader Attributes Uniforms Varyings
quadShader =
    [glsl| quad |]


rect : Uniforms -> Varyings -> { gl_FragColor : Vec4 }
rect u v =
    let
        pixelsPerTile =
            30

        e =
            0.5 / pixelsPerTile

        {-
              0               1                            1                     0
              |------|--------|----------------------------|----------|----------|
           -edge-e  -edge  -edge+e                      edge-e      edge      edge+e
        -}
        mirrorStep edge p =
            smoothstep ( -edge - e, -edge + e, p ) - smoothstep ( edge - e, edge + e, p )

        strokeSize =
            u.dimensions / 2 + u.strokeWidth

        fillSize =
            u.dimensions / 2 - u.strokeWidth

        alpha =
            mirrorStep ( u.strokeSize.x, v.localPosition.x ) * mirrorStep ( u.strokeSize.y, v.localPosition.y )

        strokeVsFill =
            mirrorStep ( u.fillSize.x, v.localPosition.x ) * mirrorStep ( u.fillSize.y, v.localPosition.y )

        color =
            mix ( u.stroke, u.fill, strokeVsFill )
    in
    { gl_FragColor = opacity * alpha * vec3to4 color 1 }


rectShader : FragmentShader Uniforms Varyings
rectShader =
    [glsl| rect |]
```

An important feature of the proposal is to be able to tell the compiler to produce an error if a specific
function cannot be compiled into shader code; in the example above I recycled the special `[glsl|...|]`
syntax, but other options are discussed below.

This feature is only to *force* the compiler to test for shader-viability when it normally wouldn't and
it is mostly for writing libraries that want to guarantee that a function can be used in or as a shader.
Whenever some piece of code isto be used in a shader, the compiler will check anyway, whether the code
is flagged as shader-viable or not.

The example assumes that the `*`operator works on vectors and matrices. This is not necessary.


Prior Art
---------
Frustratingly, there doesn't seem to be any prior art on this subject.
Game engines such as Unity 3d or Godot Engine all have their own shading language,
usually a dialect of GLSL with a few extensions here and there, but the main
composition system they provide is a visual editor.



Disadvantages
-------------

### Requires syntax extension
IMHO this is by far the main disadvantage.

It is super important to have a way to express explicitly whether a function can be compiled or not into shader code.
This is necessary so that proper type checking can happen, libraries can make guarantees of shader-viability and
the documentation generated for these libraries can automatically make these guarantees obvious.

Ideally, adding a new `FragmentShader` or `VertexShader` declaration, as in the example above, shouldn't be needed
and the funciton declaration would be all that is needed.
However, the function declaration would need some sort of modifier that doesn't get in the way of the function
being used as a normal function.

Maybe something like Haskell's ["magic hash"](https://downloads.haskell.org/~ghc/7.6.2/docs/html/users_guide/syntax-extns.html#magic-hash)
extension could be used:
```elm
rect # FragmentShader : Uniforms -> Varyings -> { gl_FragColor : Vec4 }
```
or even just
```elm
mirrorStep# : Float -> Float -> Float
mirrorStep# edge p =
    smoothstep ( -edge - e, -edge + e, p ) - smoothstep ( edge - e, edge + e, p )
```
but this is probably more occult than Elm should be.


### Performance
Transpiling Elm to GLSL *will* result in performance loss.
However, I think that the worst offenders can be tackled.
The main concern is mutability, in particular inside iteration loops.

Mutability is important when dealing with big chunks of data, because every
change requires an entirely new chunk to be allocated.
However, this is not a concern for shaders, since by large they mutate only
single variables.

While new variables are relatively cheap to declare, a possible optimization
for the compiler would be to reuse old variables that aren't used downstream.
*This optimization would also benefit normal Elm to JS transpiling.*

Regarding iteration, `fold` and `reduce` can be performed over records, then
the iterating function and the record can be inlined.
These features are not trivial to implement in the compiler, but should address
most of the performance issues.


### Large project
Implementing an emitter from the Elm AST to GLSL is not a small undertaking,
especially in light of the performance problems above.

However, *who* works on the project does make a difference.
The first iteration of the current proposal could be implemented, tested and used
entirely with elm-in-elm, without any need to change the official Elm compiler.
This means that, instead on relying on Evan, who has already a lot on his hands,
the work can be done by the larger community.
When and if the proposal has shown its merit against real-world usage, then
the Elm compiler can adopt it.


### Inability to cut & paste GLSL from the wild
This is the same problem of Elm having no "escape hatch" to JavaScript.
While annoying, in the long run I think it will drive the community to produce
better code and great libraries.
I personally find that a lot of shaders found in the wild are "write-only", not
very easy to parse and understand, but of course YMMV.



Hoped Advantage
---------------

Shaders become first-class citizens of the Elm ecosystem.

Because shaders are written in Elm, everything that makes Elm good to use
would work with shaders out of the box.

Case in point: elm-in-elm: I don't have to write a GLSL parser because I have a
parser (being) written already, optimizations and all.

In fact, thanks to this, I can write the shader transpiler without touching the
official Elm compiler.
I am using the code written by people who are not even particularly interested in
shaders, how awesome is this!?

We get run-time compiling for free and how much else?

Full static checking, "if it compiles it runs".

`elm-format`.

Fuzzy testing.

Tree-shaking / dead code elimination.

Package, library and docs management.

IDEs, syntax-highlightning, inline documentation... stuff that makes a difference
in your programming life, especially for newcomers.

What if in the future someone develops a visual editor for Elm?
All of the sudden, without writing a line of code, we have a visual shader editor.

To me all this is a massive advantage and alone offsets all the disadvantages listed
above.



Other advantages
----------------

### Can be used with normal Elm code
It's Elm, so the *same* shader function can be used inside the shader AND inside normal code.

For example, this would allow to share vector and matrix transforms between the collision
detection algorithm or the physics engine and the shader, ensuring the two consistently apply
exactly the same transform.

Another application would be preprocessing assets, saving the user from having to write color
manipulation code twice and again ensuring consistency.


### Can be developed by the community
As mentioned above, this doesn't load Evan with more stuff.


### Single syntax
Elm would rid itself of the awkward "language embedded in a language" it currently has to deal with.
Parser, formatter, syntax-highlighting, it's all a single syntax.
Newcomers can write shaders without learning GLSL.



Implementation Details
======================

### Recursion
Because [for loops are extremely limited in GLSL](https://stackoverflow.com/questions/16039515/glsl-for-loop-array-index#26480937)
it is likely that recursion proper cannot be implemented, not even with tail-call optimization.


### Custom types
Limited, non-recursive custom types can be implemented via `struct`.
```elm
type SomeCustomType
  = Zero
  | One Vec3
  | Two Vec3 Float
```

```
struct SomeCustomType {
  int constructorId;
  vec3 vec3_1;
  float float_1;
};
```
This is not very memory efficient, but adds a really nice feature to shaders.


### Swizzling
I'm not convinced that Swizzling is necessary.
Once we have modules, the user can cheaply declare and `import` whatever getters and
setters they want.

Still, it is useful to consider how the feature could be implemented.
Normal functions would probably be the way to go.

The main problem is that we'd need *lots* of functions.
The possible coordinate names sets are : {x, y, z, w}, {r, g, b, a}, {s, t, p, q}.
For each set, all the possible combinations with 1, 2, 3 or 4 names are possible:
```
get_x : { v | x } -> Float
get_xy : { v | x, y } -> Vec2
get_xx : { v | x } -> Vec2
get_xxzz : { v | x, z } -> Vec4
get_xyzw : { v | x, y, z, w } -> Vec4
...

get_r = get_x
get_rg = get_xy
...

set_x : Float -> { v | x } -> { v | x }
...
```
Considering that probably doesn't make sense to allow mixing coordinate sets in swizzling functions
(`get_xrgb`) we're talking about 256 + 64 + 16 + 4 = 340 get functions and another 340 set functions,
plus the aliases for the different sets.

The baseline solution is to generate an Elm module that contains all of them.
The module would be about 100K bytes in size, and parsing it could significantly affect compile time.
While this might be necessary for the JavaScript emitter, the GLSL emitter could ignore the specific
module and generate the functions directly in the AST.

At this point however, it might be just better to let the user define whatever functions they need.


### Function overloading
IMHO function overloading does not help making the code more readable.
Every overloadable GLSL function should be broken down in its possible variants, explicitly named.
https://www.shaderific.com/glsl-functions
```elm
radians : Float -> Float
radians2 : Vec2 -> Vec2
radians3 : Vec3 -> Vec3
radians4 : Vec4 -> Vec4
```


### Operator Overloading
Currently Elm does not allow infix operators for vector and matrices operations, relying
instead on functions and pipes:
```elm
newPosition =
    velocity
        |> Vec2.scale (speed * dt)
        |> Vec2.add currentPosition
```

If, in general, this is the best way to express linear algebra, then we can use
it in our shaders, problem solved.

So let's instead assume that the current Elm way is not really optimal.

We could say that since Elm and GLSL have different concerns, it makes sense
for Elm not go out of its way to handle those.
However, the moment you decide to use WebGL within Elm, *linear algebra
operations in Elm become a major concern*.

Further, in my limited experience, I find that it would be very useful to express
linear algebra operations in a single way that can be used both in the main thread
and within a shader (see [Can be used with Elm code] above).

TL;DR: I think that the shaders should use whatever Elm uses for vector and
matrices operations.
If whetever Elm uses is not good enough then Elm should be improved.
