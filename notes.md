Problems
========

* When *declaring* a function:
  - Functions cannot be declared within other functions
  - Functions can use symbols from the ancestors functions scope
  => Flatten functions
    - move all functions declarations in the root scope
    - add arguments to the functions to pass all the symbols needed
    ! because of these new arguments, some function calls will become partial applications


* When *calling* a function:
  - One of the arguments might be a function itself, possibly partially applied
  => create a union type to represent a function reference and the partially applied args


    - For every function, for every argument, if the argument type contains a function
        - Ensure that there is a union type dedicated to that function type

    - For every partial function call, if the argument is a function or a closure
        - Ensure that there is a constructor, for the





map : (Int -> Int) -> Monad -> Monad
map someFunction someMonad =
  case someMonad of
    Blah ->
      Blah

    Meh value ->
      Meh (someFunction value)



aFunThatUsesMap =
  map (zoop 4 2) monadedValue










Call
  { fn =
        Call
          { fn = "zoop"
          , arg = (4 + 2)
          }
  , arg = 2
  }


partial0 =
  { fn = "zoop"
  , args = [ 4 ]
  }
  -> and add constructor



partial1 =
  { fn = "zoop"
  , args = [4, 2]
  }
  -> and addconstructor





case expr of
  Call fn arg ->
    if fn is closure then




Flatten functions
=================

Before:
```
someFunction =
    \a ->
      \b ->
        a + b
```

After:
```
someFunction =
    \a -> f0 a b

f0 = \a b ->
    a + b
```


