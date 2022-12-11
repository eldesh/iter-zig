const std = @import("std");

const meta = @import("../meta.zig");
const tuple = @import("../tuple.zig");
const concept = @import("../concept.zig");

const trait = std.meta.trait;
const math = std.math;
const assert = std.debug.assert;
const assertEqualTupleType = meta.assertEqualTupleType;

const Tuple1 = tuple.Tuple1;
const Tuple2 = tuple.Tuple2;

const Func = meta.Func;
const toFunc = meta.toFunc;
const toFunc2 = meta.toFunc2;

pub fn MakePeekable(comptime D: fn (type) type, comptime Iter: type) type {
    comptime {
        assert(concept.isIterator(Iter));
        return struct {
            pub const Self: type = @This();
            pub const Item: type = Iter.Item;
            pub usingnamespace D(@This());

            iter: Iter,
            peeked: ?Iter.Item,

            pub fn new(iter: Iter) Self {
                var it = iter;
                const peeked = it.next();
                return .{ .iter = it, .peeked = peeked };
            }

            pub fn peek(self: *Self) ?*const Item {
                return self.peek_mut();
            }

            pub fn peek_mut(self: *Self) ?*Item {
                if (self.peeked) |*val|
                    return val;
                return null;
            }

            pub fn next_if(self: *Self, func: Func(*const Item, bool)) ?Item {
                if (self.peek()) |peeked| {
                    // if and only if the func() returns true for the next value, it is consumed.
                    if (func(peeked))
                        return self.next();
                }
                return null;
            }

            pub usingnamespace if (meta.basis.isPartialEq(*const Iter.Item))
                struct {
                    // derive `next_if_eq` inplace
                    pub fn next_if_eq(self: *Self, expected: *const Item) ?Item {
                        if (self.peek()) |peeked| {
                            // if and only if the `peeked` value is equals to `expected`, it is consumed.
                            if (meta.basis.PartialEq.eq(peeked, expected))
                                return self.next();
                        }
                        return null;
                    }
                }
            else
                struct {};

            pub fn next(self: *Self) ?Item {
                const peeked = self.peeked;
                self.peeked = self.iter.next();
                return peeked;
            }
        };
    }
}

pub fn MakeCycle(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    comptime assert(meta.basis.isClonable(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        orig: Iter,
        iter: Iter,

        pub fn new(iter: Iter) Self {
            return .{ .orig = iter, .iter = meta.basis.Clone.clone(iter) catch unreachable };
        }

        pub fn next(self: *Self) ?Item {
            var fst_elem = false;
            while (true) : (self.iter = meta.basis.Clone.clone(self.orig) catch unreachable) {
                if (self.iter.next()) |val| {
                    return val;
                }
                if (fst_elem)
                    return null;
                fst_elem = true;
            }
            unreachable;
        }
    };
}

pub fn MakeCopied(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    comptime assert(meta.basis.isCopyable(Iter.Item));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = meta.deref_type(Iter.Item);
        pub usingnamespace D(@This());

        iter: Iter,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                return if (comptime trait.isSingleItemPtr(Iter.Item)) val.* else val;
            }
            return null;
        }
    };
}

pub fn MakeCloned(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    comptime assert(meta.basis.isClonable(Iter.Item));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = meta.basis.Clone.ResultType(Iter.Item);
        pub usingnamespace D(@This());

        iter: Iter,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                return meta.basis.Clone.clone(val);
            }
            return null;
        }
    };
}

pub fn MakeZip(comptime D: fn (type) type, comptime Iter: type, comptime Other: type) type {
    comptime assert(concept.isIterator(Iter));
    comptime assert(concept.isIterator(Other));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = tuple.Tuple2(Iter.Item, Other.Item);
        pub usingnamespace D(@This());

        iter: Iter,
        other: Other,

        pub fn new(iter: Iter, other: Other) Self {
            return .{ .iter = iter, .other = other };
        }

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |it| {
                if (self.other.next()) |jt| {
                    return tuple.tuple2(it, jt);
                }
                return null;
            }
            return null;
        }
    };
}

pub fn MakeFlatMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type, comptime U: type) type {
    comptime assert(concept.isIterator(Iter));
    comptime assert(concept.isIterator(U));
    comptime assert(F == fn (Iter.Item) U);

    const Map = Func(Iter.Item, U);
    return struct {
        pub const Self: type = @This();
        pub const Item: type = U.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        f: Map,
        curr: ?U,

        pub fn new(iter: Iter, f: Map) Self {
            return .{ .iter = iter, .f = f, .curr = null };
        }

        pub fn next(self: *Self) ?Item {
            if (self.curr == null) {
                self.curr = if (self.iter.next()) |item| self.f(item) else null;
            }
            while (self.curr) |_| : (self.curr = if (self.iter.next()) |item| self.f(item) else null) {
                if (self.curr.?.next()) |curr| {
                    return curr;
                }
            }
            return null;
        }
    };
}

pub fn PartialCmp(comptime Item: type) type {
    comptime assert(meta.basis.isPartialOrd(Item));
    return struct {
        pub fn partial_cmp(iter: anytype, other: anytype) ?math.Order {
            const Iter = @TypeOf(iter);
            const Other = @TypeOf(other);
            comptime assert(Iter.Item == Item);
            comptime assert(Other.Item == Item);
            var it = iter;
            var ot = other;

            while (it.next()) |lval| {
                if (ot.next()) |rval| {
                    if (meta.basis.PartialOrd.partial_cmp(lval, rval)) |ord| {
                        switch (ord) {
                            .eq => continue,
                            .lt, .gt => return ord,
                        }
                    } else return null;
                } else {
                    return .gt;
                }
            }
            return if (ot.next()) |_| .lt else .eq;
        }
    };
}

pub fn Cmp(comptime Item: type) type {
    comptime assert(meta.basis.isOrd(Item));
    return struct {
        pub fn cmp(iter: anytype, other: anytype) math.Order {
            const Iter = @TypeOf(iter);
            const Other = @TypeOf(other);
            comptime assert(Iter.Item == Item);
            comptime assert(Other.Item == Item);
            var it = iter;
            var ot = other;

            while (it.next()) |lval| {
                if (ot.next()) |rval| {
                    const ord = meta.basis.Ord.cmp(lval, rval);
                    switch (ord) {
                        .eq => continue,
                        .lt, .gt => return ord,
                    }
                } else {
                    return .gt;
                }
            }
            return if (ot.next()) |_| .lt else .eq;
        }
    };
}

pub fn MakeFlatten(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    comptime assert(concept.isIterator(Iter.Item));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        curr: ?Iter.Item,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter, .curr = null };
        }

        pub fn next(self: *Self) ?Item {
            if (self.curr == null)
                self.curr = self.iter.next();
            while (self.curr) |_| : (self.curr = self.iter.next()) {
                if (self.curr.?.next()) |curr| {
                    return curr;
                }
            }
            return null;
        }
    };
}

pub fn MakeMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type) type {
    comptime assert(concept.isIterator(Iter));
    const G = comptime if (meta.newer_zig091) toFunc(F) else F;
    return struct {
        pub const Self: type = @This();
        pub const Item: type = meta.codomain(F);
        pub usingnamespace D(@This());

        f: G,
        iter: Iter,

        pub fn new(f: G, iter: Iter) Self {
            return .{ .f = f, .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |item| {
                return self.f(item);
            } else {
                return null;
            }
        }
    };
}

pub fn MakeFilter(comptime D: fn (type) type, comptime Iter: type, comptime P: type) type {
    const Pred = comptime if (meta.newer_zig091) toFunc(P) else P;
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        pred: Pred,
        iter: Iter,

        pub fn new(pred: Pred, iter: Iter) Self {
            return .{ .pred = pred, .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |item| {
                if (self.pred(item)) {
                    return item;
                }
            }
            return null;
        }
    };
}

pub fn MakeFilterMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type) type {
    comptime assert(concept.isIterator(Iter));
    comptime assert(meta.is_unary_func_type(F));
    comptime assert(trait.is(.Optional)(meta.codomain(F)));
    const G = comptime if (meta.newer_zig091) toFunc(F) else F;
    return struct {
        pub const Self: type = @This();
        pub const Item: type = std.meta.Child(meta.codomain(F));
        pub usingnamespace D(@This());

        f: G,
        iter: Iter,

        pub fn new(f: G, iter: Iter) Self {
            return .{ .f = f, .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |item| {
                if (self.f(item)) |v| {
                    return v;
                }
            }
            return null;
        }
    };
}

pub fn MakeChain(comptime D: fn (type) type, comptime Iter1: type, comptime Iter2: type) type {
    comptime assert(concept.isIterator(Iter1));
    comptime assert(concept.isIterator(Iter2));
    comptime assert(Iter1.Item == Iter2.Item);
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter1.Item;
        pub usingnamespace D(@This());

        iter1: Iter1,
        iter2: Iter2,
        iter1end: bool,

        pub fn new(iter1: Iter1, iter2: Iter2) Self {
            return .{ .iter1 = iter1, .iter2 = iter2, .iter1end = false };
        }

        pub fn next(self: *Self) ?Item {
            if (!self.iter1end) {
                if (self.iter1.next()) |v| {
                    return v;
                } else {
                    self.iter1end = true;
                    return self.iter2.next();
                }
            } else {
                return self.iter2.next();
            }
        }
    };
}

pub fn MakeEnumerate(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Tuple2(Iter.Item, usize);
        pub usingnamespace D(@This());

        iter: Iter,
        count: usize,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter, .count = 0 };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |v| {
                const count = self.count;
                self.count += 1;
                return tuple.tuple2(v, count);
            }
            return null;
        }
    };
}

pub fn MakeTake(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        take: usize,

        pub fn new(iter: Iter, take: usize) Self {
            return .{ .iter = iter, .take = take };
        }

        pub fn next(self: *Self) ?Item {
            if (0 < self.take) {
                self.take -= 1;
                return self.iter.next();
            }
            return null;
        }
    };
}

pub fn MakeTakeWhile(comptime D: fn (type) type, comptime Iter: type, comptime P: type) type {
    comptime assert(concept.isIterator(Iter));
    const Q = comptime if (meta.newer_zig091) toFunc(P) else P;
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        pred: Q,
        take: bool,

        pub fn new(iter: Iter, pred: Q) Self {
            return .{ .iter = iter, .pred = pred, .take = true };
        }

        pub fn next(self: *Self) ?Item {
            if (self.take) {
                if (self.iter.next()) |v| {
                    if (self.pred(&v))
                        return v;
                }
                self.take = false;
            }
            return null;
        }
    };
}

pub fn MakeSkip(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        skip: usize,

        pub fn new(iter: Iter, skip: usize) Self {
            return .{ .iter = iter, .skip = skip };
        }

        pub fn next(self: *Self) ?Item {
            while (0 < self.skip) : (self.skip -= 1) {
                // TODO: destroy if the aquired value is owned
                _ = self.iter.next();
            }
            return self.iter.next();
        }
    };
}

pub fn MakeSkipWhile(comptime D: fn (type) type, comptime Iter: type, comptime P: type) type {
    comptime assert(concept.isIterator(Iter));
    const Q = comptime if (meta.newer_zig091) toFunc(P) else P;
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        pred: Q,
        skip: bool,

        pub fn new(iter: Iter, pred: Q) Self {
            return .{ .iter = iter, .pred = pred, .skip = true };
        }

        pub fn next(self: *Self) ?Item {
            if (self.skip) {
                while (self.iter.next()) |v| {
                    if (self.pred(&v)) {
                        continue;
                    } else {
                        self.skip = false;
                        return v;
                    }
                }
                self.skip = false;
            }
            return self.iter.next();
        }
    };
}

pub fn MakeInspect(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        func: Func(*const Iter.Item, void),

        pub fn new(iter: Iter, func: Func(*const Iter.Item, void)) Self {
            return .{ .iter = iter, .func = func };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                self.func(&val);
                return val;
            }
            return null;
        }
    };
}

pub fn MakeMapWhile(comptime F: fn (type) type, comptime I: type, comptime P: type) type {
    comptime assert(concept.isIterator(I));
    comptime assertEqualTupleType(Tuple1(I.Item).StdTuple, meta.domain(P));
    comptime assert(trait.is(.Optional)(meta.codomain(P)));
    const Q = comptime if (meta.newer_zig091) toFunc(P) else P;
    return struct {
        pub const Self: type = @This();
        pub const Item: type = std.meta.Child(meta.codomain(P));
        pub usingnamespace F(@This());

        iter: I,
        pred: Q,

        pub fn new(iter: I, pred: Q) Self {
            return .{ .iter = iter, .pred = pred };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                return self.pred(val);
            }
            return null;
        }
    };
}

pub fn MakeStepBy(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        step_by: usize,

        pub fn new(iter: Iter, step_by: usize) Self {
            assert(0 < step_by);
            return .{ .iter = iter, .step_by = step_by };
        }

        pub fn next(self: *Self) ?Item {
            var step = self.step_by - 1;
            var item = self.iter.next();
            while (0 < step) : (step -= 1) {
                // TODO: destroy if the aquired value is owned
                _ = self.iter.next();
            }
            return item;
        }
    };
}

pub fn MakeScan(comptime D: fn (type) type, comptime Iter: type, comptime St: type, comptime F: type) type {
    comptime assert(concept.isIterator(Iter));
    comptime assert(meta.eqTupleType(Tuple2(*St, Iter.Item).StdTuple, meta.domain(F)));

    const G = comptime if (meta.newer_zig091) toFunc2(F) else F;
    return struct {
        pub const Self: type = @This();
        pub const Item: type = std.meta.Child(meta.codomain(F));
        pub usingnamespace D(@This());

        iter: Iter,
        state: St,
        f: G,

        pub fn new(iter: Iter, initial_state: St, f: G) Self {
            return .{ .iter = iter, .state = initial_state, .f = f };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                return self.f(&self.state, val);
            } else {
                return null;
            }
        }
    };
}

pub fn MakeFuse(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(concept.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        // 'null' has been occurred
        none: bool,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter, .none = false };
        }

        pub fn next(self: *Self) ?Item {
            if (self.none)
                return null;
            if (self.iter.next()) |val| {
                return val;
            } else {
                self.none = true;
                return null;
            }
        }
    };
}

/// An iterator that yields nothing
pub fn MakeEmpty(comptime D: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = T;
        pub usingnamespace D(@This());

        pub fn new() Self {
            return .{};
        }

        pub fn next(self: *Self) ?Item {
            _ = self;
            return null;
        }
    };
}

/// An iterator that yields an element exactly once.
pub fn MakeOnce(comptime D: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = T;
        pub usingnamespace D(@This());

        value: ?T,
        pub fn new(value: T) Self {
            return .{ .value = value };
        }

        pub fn next(self: *Self) ?Item {
            if (self.value) |value| {
                self.value = null;
                return value;
            }
            return null;
        }
    };
}

/// An iterator that repeatedly yields a certain element indefinitely.
pub fn MakeRepeat(comptime D: fn (type) type, comptime T: type) type {
    comptime assert(meta.basis.isClonable(T));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = meta.basis.Clone.ResultType(T);
        pub usingnamespace D(@This());

        value: T,
        pub fn new(value: T) Self {
            return .{ .value = value };
        }

        pub fn next(self: *Self) ?Item {
            return meta.basis.Clone.clone(self.value);
        }
    };
}
