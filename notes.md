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
  - The function might be only partially applied => create a struct that holds the applied args?
  ? What when two closures of the same type must contain args of different type?
  => If a function returns a closure, add the missing argumets



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


