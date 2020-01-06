Problems:

* When *declaring* a function:
  - Functions cannot be declared within other functions
  - Functions can use symbols from the ancestors functions scope
  => Flatten functions
    - move all functions declarations in the root scope
    - add arguments to the functions to pass all the symbols needed
    ! because of these new arguments, some functions call will becoe closures


* When *calling* a function:
  - The function might be only partially applied => create a struct that holds the applied args?
  ? What when two closures of the same type must contain args of different type?
  => If a function returns a closure, add the missing argumets



1) Flatten functions

```
    someFunction =
        \a ->
            if a then
                Maybe.map (\x -> x * x + a) someValue

            else
                (\y z -> y + 2 + z) 55
```

becomes:

```
    someFunction_ =
        \a ->
            if a then
                Maybe.map (f0 a) someValue

            else
                f1 55


    f0 =
        \a -> \x -> x * x + a


    f1 =
        \y -> \z -> y + 2 + z
```

