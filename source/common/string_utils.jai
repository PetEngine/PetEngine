#scope_export

ntStringLength :: inline (nt_string : [] $T/ALLOWED_CHAR_TYPES) -> s64 #no_context {
    for nt_string {
        if it == 0 {
            return it_index;
        }
    }
    return nt_string.count;
}

ntStringLength :: inline (nt_string : *$T/ALLOWED_CHAR_TYPES) -> s64 #no_context {
    start := nt_string;
    while nt_string.* {
        nt_string += 1;
    }
    return nt_string - start;
}

ntStringCompare :: (a : [] $T/ALLOWED_CHAR_TYPES, b : [] T) -> s64 #no_context {
    if a.count <= 0 && b.count <= 0 return 0; // both empty

    if a.count < b.count return -1;
    if a.count > b.count return  1;

    count := a.count;
    a_it  := a.data;
    b_it  := b.data;

    while count > 0 && a_it.* == b_it.* {
        count -= 1;
        a_it  += 1;
        b_it  += 1;
    }

    a_s64 : s64 = a_it.*;
    b_s64 : s64 = b_it.*;
    return a_s64 - b_s64;
}

ntStringCompare :: (a : *$T/ALLOWED_CHAR_TYPES, b : *T) -> s64 #no_context {
    if !a && !b return 0; // both empty

    while a.* && a.* == b.* {
        a += 1;
        b += 1;
    }

    a_s64 : s64 = a.*;
    b_s64 : s64 = b.*;
    return a_s64 - b_s64;
}

advance :: inline (s : *string, amount := 1) {
    assert(amount > 0, "amount should be > 0. amount = %", amount);
    assert(s.count >= amount, "s.count should be >= amount. s.count = %, amount = %", s.count, amount);

    s.count -= amount;
    s.data  += amount;
}

Callback :: #type (char : u8) -> bool #no_context;

advanceWhile :: (s : *string, callback : Callback) -> (old_start : *u8) #no_context {
    old_start := s.data;

    end := s.data + s.count;
    while s.data < end && callback(s.data.*) {
        s.data += 1;
    }
    s.count = end - s.data;

    return old_start;
}

cutWhile :: (s : *string, callback : Callback) #no_context {
    it := s.data + s.count - 1;
    while it >= s.data && callback(it.*) {
        it -= 1;
    }
    s.count = it - s.data + 1;
}

substring :: inline (source : string, offset : s64, $$count : s64 = -1) -> string {
    if offset >= source.count {
        return "";
    }

    assert(offset >=  0, "offset should be >= 0, offset = %", offset);
    assert(count  >= -1, "count should be >= -1, count = %", count);

    substr : string = ---;
    substr.data = source.data + offset;

    #if is_constant(count) {
        #if count == -1 {
            substr.count = source.count - offset;
        } else {
            assert(count <= source.count - offset);
            substr.count = count;
        }
    } else {
        if count == -1 {
            substr.count = source.count - offset;
        } else {
            assert(count <= source.count - offset);
            substr.count = count;
        }
    }

    return substr;
}

appendToString :: (dest : *string, dest_capacity : s64, to_append : ..string) {
    for to_append {
        assert(dest.count + it.count <= dest_capacity,
               "String overflow: occupied: %, requested to append: %, capacity: %",
               dest.count, it.count, dest_capacity);

        memcpy(dest.data + dest.count, it.data, it.count);
        dest.count += it.count;
    }
}

getLine :: (stream : *string, $trim_line := true) -> string #no_context {
    line := string.{ data = stream.data };

    end := stream.data + stream.count;
    while stream.data < end && stream.data.* != #char "\n" && stream.data.* != #char "\r" {
        stream.data += 1;
    }
    stream.count = end - stream.data;

    line.count = cast(s64) (stream.data - line.data);

    while stream.data < end && (stream.data.* == #char "\n" || stream.data.* == #char "\r") {
        stream.data += 1;
    }
    stream.count = end - stream.data;

    #if trim_line {
        trim(*line);
    }

    return line;
}

trimLeft :: (s : *string) -> (old_start : *u8) #no_context {
    return inline advanceWhile(s, isSpace);
}

trimRight :: (s : *string) #no_context {
    inline cutWhile(s, isSpace);
}

trim :: (s : *string) -> (old_start : *u8) #no_context {
    old_start := inline trimLeft(s);
    inline trimRight(s);
    return old_start;
}

isDigit :: inline (char : u8) -> bool {
    return #char "0" <= char && char <= #char "9";
}

isAlpha :: inline (char : u8) -> bool {
    return (#char "a" <= char && char <= #char "z")
        || (#char "A" <= char && char <= #char "Z");
}

isAlNum :: inline (char : u8) -> bool {
    return isAlpha(char) || isDigit(char);
}

isSpace :: inline (char : u8) -> bool #no_context {
    return char == #char " "
        || char == #char "\t"
        || char == #char "\n"
        || char == #char "\r"
        || char == 0x0C  // Warning: Unknown escape sequence '\f' in string constant!
        || char == 0x0B; // Warning: Unknown escape sequence '\v' in string constant!
}

#scope_file

ALLOWED_CHAR_TYPES :: Type.[
    u8, u16, u32,
];
