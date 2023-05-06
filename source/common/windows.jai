#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

#scope_export

HANDLE                :: *void;
HINSTANCE             :: HANDLE;
HICON                 :: HANDLE;
HCURSOR               :: HICON;
HBRUSH                :: HANDLE;
HWND                  :: HANDLE;
HMODULE               :: HINSTANCE;
HLOCAL                :: HANDLE;
HMENU                 :: HANDLE;
DPI_AWARENESS_CONTEXT :: HANDLE;

BOOL      :: s32;
CHAR      :: s8;
WCHAR     :: s16;
INT_PTR   :: s64;
UINT_PTR  :: u64;
LONG_PTR  :: s64;
ULONG_PTR :: u64;
SIZE_T    :: u64; // We target only 64-bit systems, so... whatever.
DWORD_PTR :: ULONG_PTR;

LPSTR   :: *CHAR;
LPCSTR  :: *CHAR;
LPWSTR  :: *WCHAR;
LPCWSTR :: *WCHAR;

WPARAM  :: UINT_PTR;
LPARAM  :: LONG_PTR;
LRESULT :: LONG_PTR;

TRUE  : BOOL : 1;
FALSE : BOOL : 0;

ATOM :: u16;

va_list :: *s8;

INVALID_HANDLE_VALUE :: cast(HANDLE) -1;

OutputDebugStringA :: (
    lpOutputString : *u8
) #foreign kernel32;

SetConsoleTextAttribute :: (
    hConsoleOutput : HANDLE,
    wAttributes    : u16
) -> BOOL #foreign kernel32;

STD_INPUT_HANDLE  :: cast,no_check(u32) -10;
STD_OUTPUT_HANDLE :: cast,no_check(u32) -11;
STD_ERROR_HANDLE  :: cast,no_check(u32) -12;

GetStdHandle :: (
  nStdHandle : u32
) -> HANDLE #foreign kernel32;

// @Cleanup: #RemoveUnused
CS_VREDRAW         : u32 : 0x00001;
CS_HREDRAW         : u32 : 0x00002;
CS_DBLCLKS         : u32 : 0x00008;
CS_OWNDC           : u32 : 0x00020;
CS_CLASSDC         : u32 : 0x00040;
CS_PARENTDC        : u32 : 0x00080;
CS_NOCLOSE         : u32 : 0x00200;
CS_SAVEBITS        : u32 : 0x00800;
CS_BYTEALIGNCLIENT : u32 : 0x01000;
CS_BYTEALIGNWINDOW : u32 : 0x02000;
CS_GLOBALCLASS     : u32 : 0x04000;
CS_DROPSHADOW      : u32 : 0x20000;

WNDPROC :: type_of(DefWindowProcW);

WNDCLASSEXW :: struct {
    cbSize        : u32;
    style         : u32;
    lpfnWndProc   : WNDPROC;
    cbClsExtra    : s32;
    cbWndExtra    : s32;
    hInstance     : HINSTANCE;
    hIcon         : HICON;
    hCursor       : HCURSOR;
    hbrBackground : HBRUSH;
    lpszMenuName  : LPCWSTR;
    lpszClassName : LPCWSTR;
    hIconSm       : HICON;
}

LPWNDCLASSEXW :: *WNDCLASSEXW;

RegisterClassExW :: (
    lpwcx : *WNDCLASSEXW
) -> ATOM #foreign user32;

UnregisterClassW :: (
    lpClassName : LPCWSTR,
    hInstance   : HINSTANCE
) -> BOOL #foreign user32;

GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT : u32 : 2;
GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS       : u32 : 4;

GetModuleHandleExW :: (
    dwFlags      : u32,
    lpModuleName : LPCWSTR,
    phModule     : *HMODULE
) -> BOOL #foreign kernel32;

FreeLibrary :: (
    hLibModule : HMODULE
) -> BOOL #foreign kernel32;

// @Cleanup: #RemoveUnused
IDI_APPLICATION :: cast,no_check(LPWSTR) cast,trunc(u16) 32512;
IDI_ERROR       :: cast,no_check(LPWSTR) cast,trunc(u16) 32513;
IDI_QUESTION    :: cast,no_check(LPWSTR) cast,trunc(u16) 32514;
IDI_WARNING     :: cast,no_check(LPWSTR) cast,trunc(u16) 32515;
IDI_INFORMATION :: cast,no_check(LPWSTR) cast,trunc(u16) 32516;
IDI_WINLOGO     :: cast,no_check(LPWSTR) cast,trunc(u16) 32517;
IDI_SHIELD      :: cast,no_check(LPWSTR) cast,trunc(u16) 32518;
IDI_HAND        :: IDI_ERROR;
IDI_ASTERISK    :: IDI_INFORMATION;
IDI_EXCLAMATION :: IDI_WARNING;

LoadIconW :: (
    hInstance  : HINSTANCE,
    lpIconName : LPCWSTR
) -> HICON #foreign user32;

// @Cleanup: #RemoveUnused
IDC_ARROW       :: cast,no_check(LPWSTR) cast,trunc(u16) 32512;
IDC_IBEAM       :: cast,no_check(LPWSTR) cast,trunc(u16) 32513;
IDC_WAIT        :: cast,no_check(LPWSTR) cast,trunc(u16) 32514;
IDC_CROSS       :: cast,no_check(LPWSTR) cast,trunc(u16) 32515;
IDC_UPARROW     :: cast,no_check(LPWSTR) cast,trunc(u16) 32516;
IDC_SIZE        :: cast,no_check(LPWSTR) cast,trunc(u16) 32640;
IDC_ICON        :: cast,no_check(LPWSTR) cast,trunc(u16) 32641;
IDC_SIZENWSE    :: cast,no_check(LPWSTR) cast,trunc(u16) 32642;
IDC_SIZENESW    :: cast,no_check(LPWSTR) cast,trunc(u16) 32643;
IDC_SIZEWE      :: cast,no_check(LPWSTR) cast,trunc(u16) 32644;
IDC_SIZENS      :: cast,no_check(LPWSTR) cast,trunc(u16) 32645;
IDC_SIZEALL     :: cast,no_check(LPWSTR) cast,trunc(u16) 32646;
IDC_NO          :: cast,no_check(LPWSTR) cast,trunc(u16) 32648;
IDC_HAND        :: cast,no_check(LPWSTR) cast,trunc(u16) 32649;
IDC_APPSTARTING :: cast,no_check(LPWSTR) cast,trunc(u16) 32650;
IDC_HELP        :: cast,no_check(LPWSTR) cast,trunc(u16) 32651;

LoadCursorW :: (
    hInstance    : HINSTANCE,
    lpCursorName : LPCWSTR
) -> HCURSOR #foreign user32;

GWLP_USERDATA : s32 : -21;

GetWindowLongPtrW :: (
    hWnd    : HWND,
    nIndex  : s32
) -> LONG_PTR #foreign user32;

SetWindowLongPtrW :: (
    hWnd      : HWND,
    nIndex    : s32,
    dwNewLong : LONG_PTR
) -> LONG_PTR #foreign user32;

WM_DESTROY          : u32 : 0x0002;
WM_SIZE             : u32 : 0x0005;
WM_CLOSE            : u32 : 0x0010;
WM_WINDOWPOSCHANGED : u32 : 0x0047;
WM_MENUCHAR         : u32 : 0x0120;
WM_DPICHANGED       : u32 : 0x02E0;

DefWindowProcW :: (
    hWnd   : HWND,
    Msg    : u32,
    wParam : WPARAM,
    lParam : LPARAM
) -> LRESULT #foreign user32;

COLOR_BACKGROUND : s32 : 1;

GetLastError :: (
) -> u32 #foreign kernel32;

FORMAT_MESSAGE_ALLOCATE_BUFFER : u32 : 0x00000100;
FORMAT_MESSAGE_IGNORE_INSERTS  : u32 : 0x00000200;
FORMAT_MESSAGE_FROM_SYSTEM     : u32 : 0x00001000;

FormatMessageA :: (
    dwFlags      : u32,
    lpSource     : *void,
    dwMessageId  : u32,
    dwLanguageId : u32,
    lpBuffer     : LPSTR,
    nSize        : u32,
    Arguments    : *va_list
) -> u32 #foreign kernel32;

LANG_ENGLISH       : u16 : 0x09;
SUBLANG_ENGLISH_US : u16 : 0x01;

MAKELANGID :: inline (primary_language : u16, secondary_language : u16) -> u16 {
    return (secondary_language << 10) | primary_language;
}

LocalFree :: (
  hMem : HLOCAL
) -> HLOCAL #foreign kernel32;

SendMessageW :: (
    hWnd   : HWND,
    Msg    : u32,
    wParam : WPARAM,
    lParam : LPARAM
) -> LRESULT #foreign user32;

WINDOWPOS :: struct {
    hwnd            : HWND;
    hwndInsertAfter : HWND;
    x               : s32;
    y               : s32;
    cx              : s32;
    cy              : s32;
    flags           : u32;
}

DestroyWindow :: (
    hWnd : HWND
) -> BOOL #foreign user32;

RECT :: struct {
    left   : s32;
    top    : s32;
    right  : s32;
    bottom : s32;
}

SWP_NOMOVE         : u32 : 0x0002;
SWP_NOZORDER       : u32 : 0x0004;
SWP_NOREDRAW       : u32 : 0x0008;
SWP_NOACTIVATE     : u32 : 0x0010;
SWP_NOCOPYBITS     : u32 : 0x0100;
SWP_NOOWNERZORDER  : u32 : 0x0200;
SWP_NOSENDCHANGING : u32 : 0x0400;
SWP_DEFERERASE     : u32 : 0x2000;
SWP_ASYNCWINDOWPOS : u32 : 0x4000;

HWND_TOP : HWND : null;

SetWindowPos :: (
    hWnd            : HWND,
    hWndInsertAfter : HWND,
    X               : s32,
    Y               : s32,
    cx              : s32,
    cy              : s32,
    uFlags          : u32
) -> BOOL #foreign user32;

GetCurrentThreadId :: (
) -> u32 #foreign kernel32;

SIZE_MINIMIZED : u32 : 1;
SIZE_MAXIMIZED : u32 : 2;

MNC_CLOSE : u32 : 1;

SW_SHOWNORMAL : s32 : 1;
SW_SHOW       : s32 : 5;

ShowWindow :: (
    hWnd     : HWND,
    nCmdShow : s32
) -> BOOL #foreign user32;

CW_USEDEFAULT : s32 : 0x8000_0000;

WS_EX_NOPARENTNOTIFY      : u32 : 0x0000_0004;
WS_EX_ACCEPTFILES         : u32 : 0x0000_0010;
WS_EX_WINDOWEDGE          : u32 : 0x0000_0100;
WS_EX_CLIENTEDGE          : u32 : 0x0000_0200;
WS_EX_NOREDIRECTIONBITMAP : u32 : 0x0020_0000;
WS_EX_OVERLAPPEDWINDOW    : u32 : WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE;

WS_OVERLAPPED       : u32 : 0x0000_0000;
WS_MAXIMIZEBOX      : u32 : 0x0001_0000;
WS_MINIMIZEBOX      : u32 : 0x0002_0000;
WS_THICKFRAME       : u32 : 0x0004_0000;
WS_SYSMENU          : u32 : 0x0008_0000;
WS_CAPTION          : u32 : 0x00C0_0000;
WS_OVERLAPPEDWINDOW : u32 : WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

CreateWindowExW :: (
    dwExStyle    : u32,
    lpClassName  : LPCWSTR,
    lpWindowName : LPCWSTR,
    dwStyle      : u32,
    X            : s32,
    Y            : s32,
    nWidth       : s32,
    nHeight      : s32,
    hWndParent   : HWND,
    hMenu        : HMENU,
    hInstance    : HINSTANCE,
    lpParam      : *void
) -> HWND #foreign user32;

AdjustWindowRectEx :: (
    lpRect    : *RECT,
    dwStyle   : u32,
    bMenu     : BOOL,
    dwExStyle : u32
) -> BOOL #foreign user32;

GetDpiForWindow :: (
    hwnd : HWND
) -> u32 #foreign user32;

GetDpiForSystem :: (
) -> u32 #foreign user32;

DPI_AWARENESS_CONTEXT_UNAWARE              :: cast,no_check(DPI_AWARENESS_CONTEXT) -1;
DPI_AWARENESS_CONTEXT_SYSTEM_AWARE         :: cast,no_check(DPI_AWARENESS_CONTEXT) -2;
DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE    :: cast,no_check(DPI_AWARENESS_CONTEXT) -3;
DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 :: cast,no_check(DPI_AWARENESS_CONTEXT) -4;
DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED    :: cast,no_check(DPI_AWARENESS_CONTEXT) -5;

SetProcessDpiAwarenessContext :: (
    value : DPI_AWARENESS_CONTEXT
) -> BOOL #foreign user32;

SetThreadDpiAwarenessContext :: (
    dpiContext : DPI_AWARENESS_CONTEXT
) -> DPI_AWARENESS_CONTEXT #foreign user32;

DPI_AWARENESS :: enum s32 {
    DPI_AWARENESS_INVALID           :: -1;
    DPI_AWARENESS_UNAWARE           ::  0;
    DPI_AWARENESS_SYSTEM_AWARE      ::  1;
    DPI_AWARENESS_PER_MONITOR_AWARE ::  2;
}

GetAwarenessFromDpiAwarenessContext :: (
    value : DPI_AWARENESS_CONTEXT
) -> DPI_AWARENESS #foreign user32;

DPI_HOSTING_BEHAVIOR :: enum s32 {
    DPI_HOSTING_BEHAVIOR_INVALID :: -1;
    DPI_HOSTING_BEHAVIOR_DEFAULT ::  0;
    DPI_HOSTING_BEHAVIOR_MIXED   ::  1;
}

SetThreadDpiHostingBehavior :: (
    value : DPI_HOSTING_BEHAVIOR
) -> DPI_HOSTING_BEHAVIOR #foreign user32;

PostMessageW :: (
    hWnd   : HWND,
    Msg    : u32,
    wParam : WPARAM,
    lParam : LPARAM
) -> BOOL #foreign user32;

POINT :: struct {
    x : s32;
    y : s32;
}

MSG :: struct {
    hwnd     : HWND;
    message  : u32;
    wParam   : WPARAM;
    lParam   : LPARAM;
    time     : u32;
    pt       : POINT;
    lPrivate : u32;
}

PM_REMOVE : u32 : 0x0001;

PeekMessageW :: (
    lpMsg         : *MSG,
    hWnd          : HWND,
    wMsgFilterMin : u32,
    wMsgFilterMax : u32,
    wRemoveMsg    : u32
) -> BOOL #foreign user32;

TranslateMessage :: (
    lpMsg : *MSG
) -> BOOL #foreign user32;

DispatchMessageW :: (
    lpMsg : *MSG
) -> LRESULT #foreign user32;

OVERLAPPED :: struct {
    Internal     : ULONG_PTR;
    InternalHigh : ULONG_PTR;
    union {
        struct {
            Offset     : u32;
            OffsetHigh : u32;
        }
        Pointer : *void;
    }
    hEvent : HANDLE;
}

WriteFile :: (
    hFile                  : HANDLE,
    lpBuffer               : *void,
    nNumberOfBytesToWrite  : u32,
    lpNumberOfBytesWritten : *u32,
    lpOverlapped           : *OVERLAPPED
) -> BOOL #foreign kernel32;

MEM_COMMIT      : u32 : 0x00001000;
MEM_RESERVE     : u32 : 0x00002000;
MEM_DECOMMIT    : u32 : 0x00004000;
MEM_LARGE_PAGES : u32 : 0x20000000;

PAGE_READWRITE : u32 : 0x04;

VirtualAlloc :: (
    lpAddress        : *void,
    dwSize           : SIZE_T,
    flAllocationType : u32,
    flProtect        : u32
) -> *void #foreign kernel32;

VirtualFree :: (
    lpAddress  : *void,
    dwSize     : SIZE_T,
    dwFreeType : u32
) -> BOOL #foreign kernel32;

SYSTEM_INFO :: struct {
    union {
        dwOemId : u32;
        struct {
            wProcessorArchitecture : u16;
            wReserved              : u16;
        }
    }
    dwPageSize                  : u32;
    lpMinimumApplicationAddress : *void;
    lpMaximumApplicationAddress : *void;
    dwActiveProcessorMask       : DWORD_PTR;
    dwNumberOfProcessors        : u32;
    dwProcessorType             : u32;
    dwAllocationGranularity     : u32;
    wProcessorLevel             : u16;
    wProcessorRevision          : u16;
}

GetSystemInfo :: (
    lpSystemInfo : *SYSTEM_INFO
) -> void #foreign kernel32;

LoadLibraryA :: (
    lpLibFileName : *s8
) -> HMODULE #foreign kernel32;

FARPROC  :: #type() -> INT_PTR #c_call;
NEARPROC :: #type() -> INT_PTR #c_call;
PROC     :: #type() -> INT_PTR #c_call;

GetProcAddress :: (
    hModule    : HMODULE,
    lpProcName : *s8
) -> FARPROC #foreign kernel32;

#scope_file

kernel32 :: #system_library "Kernel32";
user32   :: #system_library "User32";
