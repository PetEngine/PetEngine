#scope_export

// @Cleanup: Clean up asserts

StaticArray :: struct(T : Type, capacity : s64) {
    count : s64;
    data  : [capacity] T;
}

operator [] :: inline (array : *StaticArray, index : s64) -> array.T #no_context {
    #if DEBUG_BUILD {
        if index >= array.count {
            write_string("[ASSERT]: StaticArray out of bounds access violation\n", true);
            debugBreakIfDebugging();
            exitProcess(1);
        }
    }

    return array.data[index];
}

operator *[] :: inline (array : *StaticArray, index : s64) -> *array.T #no_context {
    #if DEBUG_BUILD {
        if index >= array.count {
            write_string("[ASSERT]: StaticArray out of bounds access violation\n", true);
            debugBreakIfDebugging();
            exitProcess(1);
        }
    }

    return *array.data[index];
}

operator []= :: inline (array : *StaticArray, index : s64, value : array.T) #no_context {
    #if DEBUG_BUILD {
        if index >= array.count {
            write_string("[ASSERT]: StaticArray out of bounds access violation\n", true);
            debugBreakIfDebugging();
            exitProcess(1);
        }
    }

    array.data[index] = value;
}

pushBack :: inline (array : *StaticArray) -> *array.T #no_context {
    #if DEBUG_BUILD {
        if array.count >= array.capacity {
            write_string("[ASSERT]: StaticArray overflow\n", true);
            debugBreakIfDebugging();
            exitProcess(1);
        }
    }

    new := *array.data[array.count];
    array.count += 1;
    return new;
}

pushBack :: inline (array : *StaticArray, element : array.T) #no_context {
    #if DEBUG_BUILD {
        if array.count >= array.capacity {
            write_string("[ASSERT]: StaticArray overflow\n", true);
            debugBreakIfDebugging();
            exitProcess(1);
        }
    }

    array.data[array.count] = element;
    array.count += 1;
}

pushBack :: inline (array : *StaticArray, data : [] array.T) #no_context {
    #if DEBUG_BUILD {
        if array.count + data.count > array.capacity {
            write_string("[ASSERT]: StaticArray overflow\n", true);
            debugBreakIfDebugging();
            exitProcess(1);
        }
    }

    memcpy(array.data.data + array.count, data.data, data.count * size_of(array.T));
    array.count += data.count;
}

reset :: inline (array : *StaticArray) #no_context {
    memset(array.data.data, 0, array.count * size_of(array.T));
    array.count = 0;
}

toView :: inline (array : StaticArray) -> [] array.T #no_context {
    return toView(array.data.data, array.count);
}

for_expansion :: (array : *StaticArray, body : Code, flags : For_Flags) #expand {
    REVERSE :: cast(bool) (flags & .REVERSE);

    last_index := array.count - 1;

    for #v2 <=REVERSE `it_index : 0 .. last_index {
        #if flags & .POINTER {
            `it := *array.data[it_index];
        } else {
            `it := array.data[it_index];
        }

        #insert(remove = #assert false "Remove statement is not supported for StaticArray") body;
    }
}
