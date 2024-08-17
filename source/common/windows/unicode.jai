#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

#scope_export

//
// ASCII to UTF16
//

ASCIIToUTF16 :: (
    ascii_string     : string,
    allocate         : (user_data : *$T, bytes : s64, alignment : s64) -> *void,
    user_data        : *T,
    $null_terminated := true
) -> [] WCHAR {
    #if DEBUG_BUILD {
        for cast([] u8) ascii_string {
            assert((it & 0x7F) == it, "The string is not ASCII");
        }
    }

    if !ascii_string {
        #if null_terminated {
            return .[ 0 ];
        } else {
            return .[];
        }
    }

    utf16_string : *WCHAR = allocate(user_data, (ascii_string.count + cast(s64) null_terminated) * size_of(WCHAR), size_of(WCHAR));

    for 0 .. ascii_string.count - 1 {
        utf16_string[it] = ascii_string[it];
    }

    #if null_terminated {
        utf16_string[ascii_string.count] = 0;
    }

    return .{ ascii_string.count, utf16_string };
}

ASCIIToUTF16 :: (utf16_string_buffer : *[$capacity] WCHAR, $$ascii_string : string, $null_terminated := true) -> s64 {
    #if null_terminated {
        #if is_constant(ascii_string) {
            #assert utf16_string_buffer.count > ascii_string.count;
        } else {
            assert(utf16_string_buffer.count > ascii_string.count);
        }
    } else {
        #if is_constant(ascii_string) {
            #assert utf16_string_buffer.count >= ascii_string.count;
        } else {
            assert(utf16_string_buffer.count >= ascii_string.count);
        }
    }

    #if DEBUG_BUILD {
        for cast([] u8) ascii_string {
            assert((it & 0x7F) == it, "The string is not ASCII");
        }
    }

    for 0 .. ascii_string.count - 1 {
        utf16_string_buffer.*[it] = ascii_string[it];
    }

    #if null_terminated {
        utf16_string_buffer.*[ascii_string.count] = 0;
    }

    return ascii_string.count;
}

//
// UTF16 to ASCII
//

UTF16ToASCII :: (
    utf16_string : [] WCHAR,
    allocate     : (user_data : *$T, bytes : s64, alignment : s64) -> *void,
    user_data    : *T
) -> string {
    if !utf16_string return "";

    #if DEBUG_BUILD {
        for utf16_string {
            assert((it & 0x7F) == it, "UTF16 string cannot be converted to ASCII");
        }
    }

    null_terminated := utf16_string[utf16_string.count - 1] == 0;
    length          := utf16_string.count - cast(s64) null_terminated;

    ascii_string : *u8 = allocate(user_data, length, size_of(u8));

    for 0 .. length - 1 {
        ascii_string[it] = cast(u8) utf16_string[it];
    }

    return .{ length, ascii_string };
}

UTF16ToASCII :: (ascii_string_buffer : *[$capacity] u8, utf16_string : [] WCHAR) -> s64 {
    if !utf16_string return 0;

    null_terminated := utf16_string[utf16_string.count - 1] == 0;
    length          := utf16_string.count - cast(s64) null_terminated;

    assert(ascii_string_buffer.count >= length);

    for 0 .. length - 1 {
        assert((utf16_string[it] & 0x7F) == utf16_string[it], "UTF16 string cannot be converted to ASCII");
        ascii_string_buffer.*[it] = cast(u8) utf16_string[it];
    }

    return length;
}

//
// UTF8 to UTF16
//

UTF8ToUTF16 :: (
    utf8_string      : string,
    allocate         : (user_data : *$T, bytes : s64, alignment : s64) -> *void,
    user_data        : *T,
    $null_terminated := true
) -> [] WCHAR {
    if !utf8_string {
        #if null_terminated {
            return .[ 0 ];
        } else {
            return .[];
        }
    }

    utf16_string_bytes : u32;
    debugCheckNT(RtlUTF8ToUnicodeN(null, 0, *utf16_string_bytes, utf8_string.data, cast(u32) utf8_string.count));

    if !utf16_string_bytes {
        #if null_terminated {
            return .[ 0 ];
        } else {
            return .[];
        }
    }

    utf16_string : PWSTR = allocate(user_data, utf16_string_bytes + cast(s64) null_terminated * size_of(WCHAR), size_of(WCHAR));
    debugCheckNT(RtlUTF8ToUnicodeN(utf16_string, utf16_string_bytes, *utf16_string_bytes, utf8_string.data, cast(u32) utf8_string.count));

    #if null_terminated {
        utf16_string[utf16_string_bytes / size_of(WCHAR)] = 0;
    }

    return .{ utf16_string_bytes / size_of(WCHAR), utf16_string };
}

UTF8ToUTF16 :: (utf16_string_buffer : *[$capacity] WCHAR, utf8_string : string, $null_terminated := true) -> s64 {
    #assert utf16_string_buffer.count > 0;

    if !utf8_string {
        #if null_terminated {
            utf16_string_buffer.*[0] = 0;
        }
        return 0;
    }

    utf16_string_length : u32;
    debugCheckNT(RtlUTF8ToUnicodeN(utf16_string_buffer.data,
                                   (utf16_string_buffer.count - cast(u32) null_terminated) * size_of(WCHAR),
                                   *utf16_string_length,
                                   utf8_string.data,
                                   cast(u32) utf8_string.count));

    utf16_string_length /= size_of(WCHAR);
    assert(utf16_string_length < utf16_string_buffer.count);

    #if null_terminated {
        utf16_string_buffer.*[utf16_string_length] = 0;
    }

    return utf16_string_length;
}

//
// UTF16 to UTF8
//

UTF16ToUTF8 :: (
    utf16_string : [] WCHAR,
    allocate     : (user_data : *$T, bytes : s64, alignment : s64) -> *void,
    user_data    : *T
) -> string {
    if !utf16_string return "";

    null_terminated    := utf16_string[utf16_string.count - 1] == 0;
    utf16_string_bytes := cast(u32) ((utf16_string.count - xx null_terminated) * size_of(WCHAR));

    utf8_string_bytes : u32;
    debugCheckNT(RtlUnicodeToUTF8N(null, 0, *utf8_string_bytes, utf16_string.data, utf16_string_bytes));
    if !utf8_string_bytes return "";

    utf8_string_data : *CHAR = allocate(user_data, utf8_string_bytes, size_of(CHAR));
    debugCheckNT(RtlUnicodeToUTF8N(utf8_string_data, utf8_string_bytes, *utf8_string_bytes, utf16_string.data, utf16_string_bytes));
    return .{ utf8_string_bytes, utf8_string_data };
}

UTF16ToUTF8 :: (utf8_string_buffer : *[$capacity] u8, utf16_string : [] WCHAR) -> s64 {
    #assert utf8_string_buffer.count > 0;

    if !utf16_string return 0;

    null_terminated    := utf16_string[utf16_string.count - 1] == 0;
    utf16_string_bytes := cast(u32) ((utf16_string.count - xx null_terminated) * size_of(WCHAR));

    utf8_string_bytes : u32;
    debugCheckNT(RtlUnicodeToUTF8N(utf8_string_buffer.data,
                                   utf8_string_buffer.count,
                                   *utf8_string_bytes,
                                   utf16_string.data,
                                   utf16_string_bytes));

    assert(utf8_string_bytes < utf8_string_buffer.count);
    return utf8_string_bytes;
}
