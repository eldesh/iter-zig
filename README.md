# iter-zig

**iter-zig** is a lazy style generic iterator combinator library written in Zig.
Where the *iterator* means that the types enumrating all element of a set of values.


## Support

This library is developped with:

- Debian (x86_64) 10.4
- Zig 0.9.1
- Zigmod r79


## Build

```sh
zig build
```


## Unit Test

To performs unit tests of iter-zig:


```sh
zig build test
```


## Example

An example program using iter-zig is provided.
The program can be performed with:

```sh
zig build example
```

Source code of this program is `src/main.zig`.


## Generate docs

To generate documentations:


```sh
zig build docs
```

A html documents would be generated under the `./docs` directory.


## Iterator Concept

**Iterator** is a generic concept that objects that enumrating a set of values.
Especially, in this library, Iterator is a value of a kind of types that satisfies follow constraints.

The constraints are:
- Have `Self` type
- Have `Item` type
- Have `next` method takes `*Self` and returns `?Item`.

Where the `Self` type specifies the type itself (equals to `@This()`), the `Item` type represents the type of elements returns from the iterator, and the `next` method returns a 'next' value of the container.
If the next value is not exists, 'null' must be returned.
The order of occurence of values are implementation defined.
However, all values must occur exactly once before 'null' is returned.


## Features

### Meta function

[The type constraints required as an Iterator](#IteratorConcept) is able to be checked by `isIterator` function statically.

```zig
comptime assert(isIterator(SliceIter(u32)));
comptime assert(!isIterator(u32));
```

When you implement a new type to be an iterator, it must ensure that `isIterator` returns `true`.


### Container Iterators

**iter-zig** provides several basic iterators that wraps standard containers.

- ArrayIter
- SliceIter
- ArrayListIter
- SinglyLinkedListIter
- BoundedArrayIter

For example, an iterator on a slice is able to be used as follows:

```zig
var arr = [_]u32{ 1, 2, 3 };
var iter = SliceIter(u32).new(arr[0..]);
try expectEqual(@as(u32, 1), iter.next().?.*);
try expectEqual(@as(u32, 2), iter.next().?.*);
try expectEqual(@as(u32, 3), iter.next().?.*);
try expectEqual(@as(?*u32, null), iter.next());
```

Further, `Const` variations are defined for each containers.
These iterators behaves as same to non-const variations except for returns const pointers.

- ArrayConstIter
- SliceConstIter
- ArrayListConstIter
- SinglyLinkedListConstIter
- BoundedArrayConstIter

```zig
var arr = [_]u32{ 1, 2, 3 };
var iter = SliceConstIter(u32).new(arr[0..]);
iter.next().?.* += 1; // error: cannot assign to constant
```

Note that, these iterators not own container values into it.
The user must release the memory holding the container if necessary.


### Range Iterator

`range` creates a Range value such that it represents a range of numbers.
For example, `range(0, 10)` means that the numbers from `0` to `10`, which is mathematics is denoted as `[0,10)`.

In particular, Range instantiated with integral type to be iterator.


```zig
var rng = range(@as(u32, 0), 3);
try expectEqual(@as(u32, 0), rng.next().?);
try expectEqual(@as(u32, 1), rng.next().?);
try expectEqual(@as(u32, 2), rng.next().?);
try expectEqual(@as(?u32, null), rng.next());
```


### Iterator Operators

All iterators defined in this library provide iterator functions below.

- peekable
- position
- cycle
- copied
- cloned
- nth
- last
- flat_map
- flatten
- partial_cmp
- cmp
- le
- ge
- lt
- gt
- sum
- product
- eq
- ne
- max
- max_by
- max_by_key
- min
- min_by
- min_by_key
- reduce
- skip
- scan
- step_by
- fold
- try_fold
- try_foreach
- for_each
- take_while
- skip_while
- map
- map_while
- filter
- filter_map
- chain
- enumerate
- all
- any
- take
- count
- find
- find_map
- inspect
- fuse
- zip


These functions are almost same to [functions on Iterator trait of Rust](https://doc.rust-lang.org/std/iter/trait.Iterator.html) except for experimental api.

#### Adaptor style iterator

Some functions above return an iterator from the iterator itself.
For that case, the functions are implemented in adaptor style.
For example, the `map` function returns a new iterator object `Map` rather than apply a function to each elements from the iterator.

```zig
var arr = [_]u32{ 1, 2, 3 };
var iter = SliceIter(u32).new(arr[0..]);
fn incr(x:u32) u32 { return x+1; }
// Calculations have not yet been performed.
var map: Map(SliceIter(u32), fn (u32) u32) = iter.map(incr);

try expectEqual(@as(u32, 2), map.next().?.*); // incr is performed
try expectEqual(@as(u32, 3), map.next().?.*); // incr is performed
try expectEqual(@as(u32, 4), map.next().?.*); // incr is performed
try expectEqual(@as(?*u32, null), map.next());
```


### Implementing Iterator

**iter-zig** allows library users to implement a new iterator type by their self.
Further, it is easy to implement all functions showed in [Iterator Operators](#iterator-operators) to your new iterator type using `DeriveIterator`.

For example, let's make an iterator `Counter` which counts from `1` to `5`.

```zig
const Counter = struct {
  pub const Self = @This();
  pub const Item = u32;
  count: u32,
  pub fn new() Self { return .{ .count = 0 }; }
  pub fn next(self: *Self) ?Item {
    self.count += 1;
    if (self.count < 6)
      return self.count;
    return null;
  }
};
```

Now we can use it as an iterator.

```zig
comptime assert(isIterator(Counter));
var counter = Counter.new();
try expectEqual(@as(u32, 1), counter.next().?);
try expectEqual(@as(u32, 2), counter.next().?);
try expectEqual(@as(u32, 3), counter.next().?);
try expectEqual(@as(u32, 4), counter.next().?);
try expectEqual(@as(u32, 5), counter.next().?);
try expectEqual(@as(?u32, null), counter.next());
```

However, `Counter` not implement utility functions like `map` or `count` etc ...
To implement these functions, use `DeriveIterator` meta function like below.

```zig
const CounterExt = struct {
  pub const Self = @This();
  pub const Item = u32;
  pub usingnamespace DeriveIterator(@This()); // Add

  count: u32,
  pub fn new() Self { return .{ .count = 0 }; }
  pub fn next(self: *Self) ?Item {
    self.count += 1;
    if (self.count < 6)
      return self.count;
    return null;
  }
};
```

In above code, `CounterExt` difference from `Counter` is only the `DeriveIterator(@This())` line.
Now, you can use all functions showed in [Iterator Operators](#iterator-operators).

```zig
fn incr(x:u32) u32 { return x+1; }
fn even(x:u32) bool { return x % 2 == 0; }
fn sum(st:*u32, v:u32) ?u32 {
  st.* += v;
  return st.*;
}
var counter = CounterExt.new();
var iter = counter
             .map(incr)     // 2,3,4,5,6
             .filter(even)  // 2,4,6
             .scan(@as(u32, 0), sum); // 2,6,12
try expectEqual(@as(u32, 2), iter.next().?);
try expectEqual(@as(u32, 6), iter.next().?);
try expectEqual(@as(u32, 12), iter.next().?);
try expectEqual(@as(?u32, null), iter.next());
```

If you can implement some method efficiently rather than using `next` method, just implement that method (in `CounterExt` in the above).
`DeriveIterator` suppresses the generation of that function.


#### Convention

**iter-zig** adopts naming conventions for implementing iterators.
First, when defining a new iterator type, the type constructor must be named `MakeT` where type `T` is a name of the type.
And the constructor should take a `Derive` function like below.

```zig
pub fn MakeCounter(comptime Derive: fn (type) type) type {
  return struct {
    pub const Self = @This();
    pub const Item = u32;
    pub usingnamespace Derive(@This());
    count: u32,
    pub fn next(self: *Self) ?Item {
      ...
    }
  };
}
```

This allows users to switch the function used for deriving.


Second, a type constructor should be named `T`.
And the constructor should forward `DeriveIterator` to `MakeT`.

```zig
pub fn Counter() type {
  return MakeCounter(DeriveIterator);
}
```

