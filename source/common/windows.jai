#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

// @Cleanup:
//    - Split everything into different files like we did it with Vulkan.

#scope_export

HANDLE :: *void;

HINSTANCE             :: *HINSTANCE__;             HINSTANCE__             :: struct { unused : s32; }
HICON                 :: *HICON__;                 HICON__                 :: struct { unused : s32; }
HCURSOR               :: *HCURSOR__;               HCURSOR__               :: struct { unused : s32; }
HBRUSH                :: *HBRUSH__;                HBRUSH__                :: struct { unused : s32; }
HWND                  :: *HWND__;                  HWND__                  :: struct { unused : s32; }
HMENU                 :: *HMENU__;                 HMENU__                 :: struct { unused : s32; }
DPI_AWARENESS_CONTEXT :: *DPI_AWARENESS_CONTEXT__; DPI_AWARENESS_CONTEXT__ :: struct { unused : s32; }
HKEY                  :: *HKEY__;                  HKEY__                  :: struct { unused : s32; }
HRAWINPUT             :: *HRAWINPUT__;             HRAWINPUT__             :: struct { unused : s32; }

HMODULE :: HINSTANCE;
HLOCAL  :: HANDLE;

BOOL      :: s32;
BOOLEAN   :: u8;
CHAR      :: s8;
WCHAR     :: s16;
INT_PTR   :: s64; // We target only 64-bit systems, so... whatever.
UINT_PTR  :: u64; // We target only 64-bit systems, so... whatever.
LONG_PTR  :: s64; // We target only 64-bit systems, so... whatever.
ULONG_PTR :: u64; // We target only 64-bit systems, so... whatever.
SIZE_T    :: ULONG_PTR;
DWORD_PTR :: ULONG_PTR;

LPSTR   :: *CHAR;
LPCSTR  :: *CHAR;
LPWSTR  :: *WCHAR;
LPCWSTR :: *WCHAR;
PCWSTR  :: *WCHAR;

WPARAM  :: UINT_PTR;
LPARAM  :: LONG_PTR;
LRESULT :: LONG_PTR;
LSTATUS :: s32;

TRUE  : BOOL : 1;
FALSE : BOOL : 0;

ATOM :: u16;

// bit 31        - 1-bit code indicating severity, where zero represents success and 1 represents failure.
// bits [30, 27] - 4-bit reserved value.
// bits [26, 16] - 11-bit code indicating responsibility for the error or warning, also known as a facility code.
// bits [15, 0]  - 16-bit code describing the error or warning.
HRESULT :: s32;

va_list :: *s8;

INVALID_HANDLE_VALUE :: cast(HANDLE) -1;

ERROR_SUCCESS             :: 0;
ERROR_FILE_NOT_FOUND      :: 2;
ERROR_PATH_NOT_FOUND      :: 3;
ERROR_ACCESS_DENIED       :: 5;
ERROR_NO_MORE_FILES       :: 18;
ERROR_SHARING_VIOLATION   :: 32;
ERROR_FILE_EXISTS         :: 80;
ERROR_INSUFFICIENT_BUFFER :: 122;
ERROR_ALREADY_EXISTS      :: 183;
ERROR_OPERATION_ABORTED   :: 995;
ERROR_NOT_FOUND           :: 1168;
ERROR_INVALID_USER_BUFFER :: 1784;

STATUS_PENDING :: 0x00000103;

SUCCEEDED :: inline ($$result : $T) -> bool {
    #assert T == u32 || T == s32 "T should be a 32-bit integer";
    return result >= ERROR_SUCCESS;
}

FAILED :: inline ($$result : $T) -> bool {
    #assert T == u32 || T == s32 "T should be a 32-bit integer";
    return result < ERROR_SUCCESS;
}

CloseHandle :: (
    handle : HANDLE
) -> BOOL #foreign kernel32;

OutputDebugStringA :: (
    lpOutputString : *u8
) #foreign kernel32;

GetConsoleMode :: (
    hConsoleHandle : HANDLE,
    lpMode         : *u32
) -> BOOL #foreign kernel32;

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

LoadLibraryA :: (
    lpLibFileName : *s8
) -> HMODULE #foreign kernel32;

FreeLibrary :: (
    hLibModule : HMODULE
) -> BOOL #foreign kernel32;

FARPROC  :: #type () -> INT_PTR #c_call;
NEARPROC :: #type () -> INT_PTR #c_call;
PROC     :: #type () -> INT_PTR #c_call;

GetProcAddress :: (
    hModule    : HMODULE,
    lpProcName : *s8
) -> FARPROC #foreign kernel32;

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

WM_DESTROY             : u32 : 0x0002;
WM_SIZE                : u32 : 0x0005;
WM_CLOSE               : u32 : 0x0010;
WM_WININICHANGE        : u32 : 0x001A;
WM_WINDOWPOSCHANGED    : u32 : 0x0047;
WM_INPUT_DEVICE_CHANGE : u32 : 0x00FE;
WM_INPUT               : u32 : 0x00FF;
WM_MENUCHAR            : u32 : 0x0120;
WM_DPICHANGED          : u32 : 0x02E0;

DefWindowProcW :: (
    hWnd   : HWND,
    Msg    : u32,
    wParam : WPARAM,
    lParam : LPARAM
) -> LRESULT #foreign user32;

// The only supported system colors since Windows 10
COLOR_WINDOW        : s32 : 5;
COLOR_WINDOWTEXT    : s32 : 8;
COLOR_HIGHLIGHT     : s32 : 13;
COLOR_HIGHLIGHTTEXT : s32 : 14;
COLOR_3DFACE        : s32 : 15;
COLOR_GRAYTEXT      : s32 : 17;
COLOR_BTNTEXT       : s32 : 18;
COLOR_HOTLIGHT      : s32 : 26;

GetSysColor :: (
    nIndex : s32
) -> u32 #foreign user32;

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

DWMWINDOWATTRIBUTE :: enum s32 {
    DWMWA_NCRENDERING_ENABLED :: 1;       // [get] Is non-client rendering enabled/disabled
    DWMWA_NCRENDERING_POLICY;             // [set] DWMNCRENDERINGPOLICY - Non-client rendering policy
    DWMWA_TRANSITIONS_FORCEDISABLED;      // [set] Potentially enable/forcibly disable transitions
    DWMWA_ALLOW_NCPAINT;                  // [set] Allow contents rendered in the non-client area to be visible on the DWM-drawn frame.
    DWMWA_CAPTION_BUTTON_BOUNDS;          // [get] Bounds of the caption button area in window-relative space.
    DWMWA_NONCLIENT_RTL_LAYOUT;           // [set] Is non-client content RTL mirrored
    DWMWA_FORCE_ICONIC_REPRESENTATION;    // [set] Force this window to display iconic thumbnails.
    DWMWA_FLIP3D_POLICY;                  // [set] Designates how Flip3D will treat the window.
    DWMWA_EXTENDED_FRAME_BOUNDS;          // [get] Gets the extended frame bounds rectangle in screen space
    DWMWA_HAS_ICONIC_BITMAP;              // [set] Indicates an available bitmap when there is no better thumbnail representation.
    DWMWA_DISALLOW_PEEK;                  // [set] Don't invoke Peek on the window.
    DWMWA_EXCLUDED_FROM_PEEK;             // [set] LivePreview exclusion information
    DWMWA_CLOAK;                          // [set] Cloak or uncloak the window
    DWMWA_CLOAKED;                        // [get] Gets the cloaked state of the window
    DWMWA_FREEZE_REPRESENTATION;          // [set] BOOL, Force this window to freeze the thumbnail without live update
    DWMWA_PASSIVE_UPDATE_MODE;            // [set] BOOL, Updates the window only when desktop composition runs for other reasons
    DWMWA_USE_HOSTBACKDROPBRUSH;          // [set] BOOL, Allows the use of host backdrop brushes for the window.
    DWMWA_USE_IMMERSIVE_DARK_MODE  :: 20; // [set] BOOL, Allows a window to either use the accent color, or dark, according to the user Color Mode preferences.
    DWMWA_WINDOW_CORNER_PREFERENCE :: 33; // [set] WINDOW_CORNER_PREFERENCE, Controls the policy that rounds top-level window corners
    DWMWA_BORDER_COLOR;                   // [set] COLORREF, The color of the thin border around a top-level window
    DWMWA_CAPTION_COLOR;                  // [set] COLORREF, The color of the caption
    DWMWA_TEXT_COLOR;                     // [set] COLORREF, The color of the caption text
    DWMWA_VISIBLE_FRAME_BORDER_THICKNESS; // [get] UINT, width of the visible border around a thick frame window
    DWMWA_SYSTEMBACKDROP_TYPE;            // [get, set] SYSTEMBACKDROP_TYPE, Controls the system-drawn backdrop material of a window, including behind the non-client area.
    DWMWA_LAST;
}

DwmSetWindowAttribute :: (
    hwnd        : HWND,
    dwAttribute : DWMWINDOWATTRIBUTE,
    pvAttribute : *void,
    cbAttribute : u32
) -> HRESULT #foreign dwmapi;

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

IsDebuggerPresent :: (
) -> BOOL #foreign kernel32;

HKEY_CLASSES_ROOT                :: cast,no_check(HKEY) 0x80000000;
HKEY_CURRENT_USER                :: cast,no_check(HKEY) 0x80000001;
HKEY_LOCAL_MACHINE               :: cast,no_check(HKEY) 0x80000002;
HKEY_USERS                       :: cast,no_check(HKEY) 0x80000003;
HKEY_PERFORMANCE_DATA            :: cast,no_check(HKEY) 0x80000004;
HKEY_PERFORMANCE_TEXT            :: cast,no_check(HKEY) 0x80000050;
HKEY_PERFORMANCE_NLSTEXT         :: cast,no_check(HKEY) 0x80000060;
HKEY_CURRENT_CONFIG              :: cast,no_check(HKEY) 0x80000005;
HKEY_DYN_DATA                    :: cast,no_check(HKEY) 0x80000006;
HKEY_CURRENT_USER_LOCAL_SETTINGS :: cast,no_check(HKEY) 0x80000007;

RRF_RT_REG_DWORD : u32 : 0x00000010;

RegGetValueW :: (
    hkey     : HKEY,
    lpSubKey : LPCWSTR,
    lpValue  : LPCWSTR,
    dwFlags  : u32,
    pdwType  : *u32,
    pvData   : *void,
    pcbData  : *u32
) -> LSTATUS #foreign advapi32;

SECURITY_ATTRIBUTES :: struct {
    nLength              : u32;
    lpSecurityDescriptor : *void;
    bInheritHandle       : BOOL;
}

THREAD_START_ROUTINE :: #type (
    lpParameter : *void
) -> u32 #c_call;

CREATE_SUSPENDED                  : u32 : 0x00000004;
STACK_SIZE_PARAM_IS_A_RESERVATION : u32 : 0x00010000;

CreateThread :: (
    lpThreadAttributes : *SECURITY_ATTRIBUTES,
    dwStackSize        : SIZE_T,
    lpStartAddress     : THREAD_START_ROUTINE,
    lpParameter        : *void,
    dwCreationFlags    : u32,
    lpThreadId         : *u32
) -> HANDLE #foreign kernel32;

SetThreadDescription :: (
    hThread             : HANDLE,
    lpThreadDescription : PCWSTR
) -> HRESULT #foreign kernel32;

ResumeThread :: (
    hThread : HANDLE
) -> u32 #foreign kernel32;

SuspendThread :: (
    hThread : HANDLE
) -> u32 #foreign kernel32;

TerminateThread :: (
    hThread    : HANDLE,
    dwExitCode : u32
) -> BOOL #foreign kernel32;

INFINITE : u32 : 0xFFFFFFFF;

WAIT_OBJECT_0  : u32 : 0x00000000;
WAIT_ABANDONED : u32 : 0x00000080;
WAIT_TIMEOUT   : u32 : 0x00000102;
WAIT_FAILED    : u32 : 0xFFFFFFFF;

WaitForSingleObjectEx :: (
    hHandle        : HANDLE,
    dwMilliseconds : u32,
    bAlertable     : BOOL
) -> u32 #foreign kernel32;

WaitForMultipleObjectsEx :: (
    nCount         : u32,
    lpHandles      : *HANDLE,
    bWaitAll       : BOOL,
    dwMilliseconds : u32,
    bAlertable     : BOOL
) -> u32 #foreign kernel32;

CreateDirectoryW :: (
    lpPathName           : LPCWSTR,
    lpSecurityAttributes : *SECURITY_ATTRIBUTES
) -> BOOL #foreign kernel32;

DELETE                   : u32 : 0x00010000;
READ_CONTROL             : u32 : 0x00020000;
WRITE_DAC                : u32 : 0x00040000;
WRITE_OWNER              : u32 : 0x00080000;
SYNCHRONIZE              : u32 : 0x00100000;
STANDARD_RIGHTS_REQUIRED : u32 : 0x000F0000;
STANDARD_RIGHTS_READ     : u32 : READ_CONTROL;
STANDARD_RIGHTS_WRITE    : u32 : READ_CONTROL;
STANDARD_RIGHTS_EXECUTE  : u32 : READ_CONTROL;
STANDARD_RIGHTS_ALL      : u32 : 0x001F0000;
SPECIFIC_RIGHTS_ALL      : u32 : 0x0000FFFF;
ACCESS_SYSTEM_SECURITY   : u32 : 0x01000000;
MAXIMUM_ALLOWED          : u32 : 0x02000000;

GENERIC_ALL     : u32 : 0x10000000;
GENERIC_EXECUTE : u32 : 0x20000000;
GENERIC_WRITE   : u32 : 0x40000000;
GENERIC_READ    : u32 : 0x80000000;

FILE_READ_DATA            : u32 : 0x0001; // file & pipe
FILE_LIST_DIRECTORY       : u32 : 0x0001; // directory
FILE_WRITE_DATA           : u32 : 0x0002; // file & pipe
FILE_ADD_FILE             : u32 : 0x0002; // directory
FILE_APPEND_DATA          : u32 : 0x0004; // file
FILE_ADD_SUBDIRECTORY     : u32 : 0x0004; // directory
FILE_CREATE_PIPE_INSTANCE : u32 : 0x0004; // named pipe
FILE_READ_EA              : u32 : 0x0008; // file & directory
FILE_WRITE_EA             : u32 : 0x0010; // file & directory
FILE_EXECUTE              : u32 : 0x0020; // file
FILE_TRAVERSE             : u32 : 0x0020; // directory
FILE_DELETE_CHILD         : u32 : 0x0040; // directory
FILE_READ_ATTRIBUTES      : u32 : 0x0080; // all
FILE_WRITE_ATTRIBUTES     : u32 : 0x0100; // all
FILE_ALL_ACCESS           : u32 : STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x1FF;
FILE_GENERIC_READ         : u32 : STANDARD_RIGHTS_READ | FILE_READ_DATA | FILE_READ_ATTRIBUTES | FILE_READ_EA | SYNCHRONIZE;
FILE_GENERIC_WRITE        : u32 : STANDARD_RIGHTS_WRITE | FILE_WRITE_DATA | FILE_WRITE_ATTRIBUTES | FILE_WRITE_EA | FILE_APPEND_DATA | SYNCHRONIZE;
FILE_GENERIC_EXECUTE      : u32 : STANDARD_RIGHTS_EXECUTE | FILE_READ_ATTRIBUTES | FILE_EXECUTE | SYNCHRONIZE;

FILE_SHARE_READ   : u32 : 0x00000001;
FILE_SHARE_WRITE  : u32 : 0x00000002;
FILE_SHARE_DELETE : u32 : 0x00000004;

CREATE_NEW        : u32 : 1;
CREATE_ALWAYS     : u32 : 2;
OPEN_EXISTING     : u32 : 3;
OPEN_ALWAYS       : u32 : 4;
TRUNCATE_EXISTING : u32 : 5;

FILE_ATTRIBUTE_READONLY              : u32 : 0x00000001;
FILE_ATTRIBUTE_HIDDEN                : u32 : 0x00000002;
FILE_ATTRIBUTE_SYSTEM                : u32 : 0x00000004;
FILE_ATTRIBUTE_DIRECTORY             : u32 : 0x00000010;
FILE_ATTRIBUTE_ARCHIVE               : u32 : 0x00000020;
FILE_ATTRIBUTE_DEVICE                : u32 : 0x00000040;
FILE_ATTRIBUTE_NORMAL                : u32 : 0x00000080;
FILE_ATTRIBUTE_TEMPORARY             : u32 : 0x00000100;
FILE_ATTRIBUTE_SPARSE_FILE           : u32 : 0x00000200;
FILE_ATTRIBUTE_REPARSE_POINT         : u32 : 0x00000400;
FILE_ATTRIBUTE_COMPRESSED            : u32 : 0x00000800;
FILE_ATTRIBUTE_OFFLINE               : u32 : 0x00001000;
FILE_ATTRIBUTE_NOT_CONTENT_INDEXED   : u32 : 0x00002000;
FILE_ATTRIBUTE_ENCRYPTED             : u32 : 0x00004000;
FILE_ATTRIBUTE_INTEGRITY_STREAM      : u32 : 0x00008000;
FILE_ATTRIBUTE_VIRTUAL               : u32 : 0x00010000;
FILE_ATTRIBUTE_NO_SCRUB_DATA         : u32 : 0x00020000;
FILE_ATTRIBUTE_EA                    : u32 : 0x00040000;
FILE_ATTRIBUTE_RECALL_ON_OPEN        : u32 : 0x00040000;
FILE_ATTRIBUTE_PINNED                : u32 : 0x00080000;
FILE_ATTRIBUTE_UNPINNED              : u32 : 0x00100000;
FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS : u32 : 0x00400000;
FILE_ATTRIBUTE_STRICTLY_SEQUENTIAL   : u32 : 0x20000000;

FILE_FLAG_OPEN_REQUIRING_OPLOCK : u32 : 0x00040000;
FILE_FLAG_FIRST_PIPE_INSTANCE   : u32 : 0x00080000;
FILE_FLAG_OPEN_NO_RECALL        : u32 : 0x00100000;
FILE_FLAG_OPEN_REPARSE_POINT    : u32 : 0x00200000;
FILE_FLAG_SESSION_AWARE         : u32 : 0x00800000;
FILE_FLAG_POSIX_SEMANTICS       : u32 : 0x01000000;
FILE_FLAG_BACKUP_SEMANTICS      : u32 : 0x02000000;
FILE_FLAG_DELETE_ON_CLOSE       : u32 : 0x04000000;
FILE_FLAG_SEQUENTIAL_SCAN       : u32 : 0x08000000;
FILE_FLAG_RANDOM_ACCESS         : u32 : 0x10000000;
FILE_FLAG_NO_BUFFERING          : u32 : 0x20000000;
FILE_FLAG_OVERLAPPED            : u32 : 0x40000000;
FILE_FLAG_WRITE_THROUGH         : u32 : 0x80000000;

CreateFileW :: (
    lpFileName            : LPCWSTR,
    dwDesiredAccess       : u32,
    dwShareMode           : u32,
    lpSecurityAttributes  : *SECURITY_ATTRIBUTES,
    dwCreationDisposition : u32,
    dwFlagsAndAttributes  : u32,
    hTemplateFile         : HANDLE
) -> HANDLE #foreign kernel32;

ReadFile :: (
    hFile                : HANDLE,
    lpBuffer             : *void,
    nNumberOfBytesToRead : u32,
    lpNumberOfBytesRead  : *u32,
    lpOverlapped         : *OVERLAPPED
) -> BOOL #foreign kernel32;

WriteFile :: (
    hFile                  : HANDLE,
    lpBuffer               : *void,
    nNumberOfBytesToWrite  : u32,
    lpNumberOfBytesWritten : *u32,
    lpOverlapped           : *OVERLAPPED
) -> BOOL #foreign kernel32;

LARGE_INTEGER :: union {
    struct {
        LowPart  : u32;
        HighPart : s32;
    }
    u : struct {
        LowPart  : u32;
        HighPart : s32;
    };
    QuadPart : s64;
}

GetFileSizeEx :: (
    hFile      : HANDLE,
    lpFileSize : *LARGE_INTEGER
) -> BOOL #foreign kernel32;

GetOverlappedResult :: (
    hFile                      : HANDLE,
    lpOverlapped               : *OVERLAPPED,
    lpNumberOfBytesTransferred : *u32,
    bWait                      : BOOL
) -> BOOL #foreign kernel32;

HasOverlappedIoCompleted :: inline (lpOverlapped : *OVERLAPPED) -> bool #no_context {
    return cast(u32) lpOverlapped.Internal != STATUS_PENDING;
}

CancelIo :: (
    hFile : HANDLE
) -> BOOL #foreign kernel32;

CancelIoEx :: (
    hFile        : HANDLE,
    lpOverlapped : *OVERLAPPED
) -> BOOL #foreign kernel32;

FILE_NOTIFY_CHANGE_FILE_NAME   : u32 : 0x00000001;
FILE_NOTIFY_CHANGE_DIR_NAME    : u32 : 0x00000002;
FILE_NOTIFY_CHANGE_ATTRIBUTES  : u32 : 0x00000004;
FILE_NOTIFY_CHANGE_SIZE        : u32 : 0x00000008;
FILE_NOTIFY_CHANGE_LAST_WRITE  : u32 : 0x00000010;
FILE_NOTIFY_CHANGE_LAST_ACCESS : u32 : 0x00000020;
FILE_NOTIFY_CHANGE_CREATION    : u32 : 0x00000040;
FILE_NOTIFY_CHANGE_SECURITY    : u32 : 0x00000100;

FindFirstChangeNotificationW :: (
    lpPathName     : LPCWSTR,
    bWatchSubtree  : BOOL,
    dwNotifyFilter : u32
) -> HANDLE #foreign kernel32;

FindNextChangeNotification :: (
    hChangeHandle : HANDLE
) -> BOOL #foreign kernel32;

FindCloseChangeNotification :: (
    hChangeHandle : HANDLE
) -> BOOL #foreign kernel32;

FILE_ACTION_ADDED            : u32 : 0x00000001;
FILE_ACTION_REMOVED          : u32 : 0x00000002;
FILE_ACTION_MODIFIED         : u32 : 0x00000003;
FILE_ACTION_RENAMED_OLD_NAME : u32 : 0x00000004;
FILE_ACTION_RENAMED_NEW_NAME : u32 : 0x00000005;

FILE_NOTIFY_INFORMATION :: struct {
    NextEntryOffset : u32;
    Action          : u32;
    FileNameLength  : u32;
    FileName        : [1] WCHAR;
}

OVERLAPPED_COMPLETION_ROUTINE :: #type (
    dwErrorCode               : u32,
    dwNumberOfBytesTransfered : u32,
    lpOverlapped              : *OVERLAPPED
) #c_call;

ReadDirectoryChangesW :: (
    hDirectory          : HANDLE,
    lpBuffer            : *void,
    nBufferLength       : u32,
    bWatchSubtree       : BOOL,
    dwNotifyFilter      : u32,
    lpBytesReturned     : *u32,
    lpOverlapped        : *OVERLAPPED,
    lpCompletionRoutine : OVERLAPPED_COMPLETION_ROUTINE
) -> BOOL #foreign kernel32;

FINDEX_INFO_LEVELS :: enum s32 {
    FindExInfoStandard;
    FindExInfoBasic;
    FindExInfoMaxInfoLevel;
}

FINDEX_SEARCH_OPS :: enum s32 {
    FindExSearchNameMatch;
    FindExSearchLimitToDirectories;
    FindExSearchLimitToDevices;
    FindExSearchMaxSearchOp;
}

FIND_FIRST_EX_CASE_SENSITIVE       : u32 : 1;
FIND_FIRST_EX_LARGE_FETCH          : u32 : 2;
FIND_FIRST_EX_ON_DISK_ENTRIES_ONLY : u32 : 4;

IO_REPARSE_TAG_SYMLINK :: 0xA000000C;

FindFirstFileExW :: (
    lpFileName        : LPCWSTR,
    fInfoLevelId      : FINDEX_INFO_LEVELS,
    lpFindFileData    : *void,
    fSearchOp         : FINDEX_SEARCH_OPS,
    lpSearchFilter    : *void,
    dwAdditionalFlags : u32
) -> HANDLE #foreign kernel32;

MAX_PATH :: 260;

FILETIME :: struct {
    dwLowDateTime  : u32;
    dwHighDateTime : u32;
}

WIN32_FIND_DATAW :: struct {
    dwFileAttributes   : u32;
    ftCreationTime     : FILETIME;
    ftLastAccessTime   : FILETIME;
    ftLastWriteTime    : FILETIME;
    nFileSizeHigh      : u32;
    nFileSizeLow       : u32;
    dwReserved0        : u32;
    dwReserved1        : u32;
    cFileName          : [MAX_PATH] WCHAR;
    cAlternateFileName : [14] WCHAR;
    dwFileType         : u32; // Obsolete. Do not use.
    dwCreatorType      : u32; // Obsolete. Do not use
    wFinderFlags       : u16; // Obsolete. Do not use
}

FindNextFileW :: (
    hFindFile      : HANDLE,
    lpFindFileData : *WIN32_FIND_DATAW
) -> BOOL #foreign kernel32;

FindClose :: (
    hFindFile : HANDLE
) -> BOOL #foreign kernel32;

GET_FILEEX_INFO_LEVELS :: enum s32 {
    GetFileExInfoStandard;
    GetFileExMaxInfoLevel;
}

WIN32_FILE_ATTRIBUTE_DATA :: struct {
    dwFileAttributes : u32;
    ftCreationTime   : FILETIME;
    ftLastAccessTime : FILETIME;
    ftLastWriteTime  : FILETIME;
    nFileSizeHigh    : u32;
    nFileSizeLow     : u32;
}

GetFileAttributesExW :: (
    lpFileName        : LPCWSTR,
    fInfoLevelId      : GET_FILEEX_INFO_LEVELS,
    lpFileInformation : *void
) -> BOOL #foreign kernel32;

CREATE_EVENT_MANUAL_RESET : u32 : 0x00000001;
CREATE_EVENT_INITIAL_SET  : u32 : 0x00000002;

EVENT_MODIFY_STATE : u32 : 0x000002;
EVENT_ALL_ACCESS   : u32 : 0x1F0003;

CreateEventExW :: (
    lpEventAttributes : *SECURITY_ATTRIBUTES,
    lpName            : LPCWSTR,
    dwFlags           : u32,
    dwDesiredAccess   : u32
) -> HANDLE #foreign kernel32;

SetEvent :: (
    hEvent : HANDLE
) -> BOOL #foreign kernel32;

SRWLOCK :: struct {
    Ptr : *void;
}

ReleaseSRWLockExclusive :: (
    SRWLock : *SRWLOCK
) #foreign kernel32;

ReleaseSRWLockShared :: (
    SRWLock : *SRWLOCK
) #foreign kernel32;

AcquireSRWLockExclusive :: (
    SRWLock : *SRWLOCK
) #foreign kernel32;

AcquireSRWLockShared :: (
    SRWLock : *SRWLOCK
) #foreign kernel32;

TryAcquireSRWLockExclusive :: (
    SRWLock : *SRWLOCK
) -> BOOLEAN #foreign kernel32;

TryAcquireSRWLockShared :: (
    SRWLock : *SRWLOCK
) -> BOOLEAN #foreign kernel32;

//
// Raw input
//

GIDC_ARRIVAL : u8 : 1;
GIDC_REMOVAL : u8 : 2;

GET_DEVICE_CHANGE_WPARAM :: inline (wparam : WPARAM) -> u8 #no_context {
    return cast(u8) (wparam & 0xFF);
}

HID_USAGE_PAGE_GENERIC : u16 : 0x01;
HID_USAGE_PAGE_GAME    : u16 : 0x05;
HID_USAGE_PAGE_LED     : u16 : 0x08;
HID_USAGE_PAGE_BUTTON  : u16 : 0x09;

HID_USAGE_GENERIC_POINTER               : u16 : 0x01;
HID_USAGE_GENERIC_MOUSE                 : u16 : 0x02;
HID_USAGE_GENERIC_JOYSTICK              : u16 : 0x04;
HID_USAGE_GENERIC_GAMEPAD               : u16 : 0x05;
HID_USAGE_GENERIC_KEYBOARD              : u16 : 0x06;
HID_USAGE_GENERIC_KEYPAD                : u16 : 0x07;
HID_USAGE_GENERIC_MULTI_AXIS_CONTROLLER : u16 : 0x08;

RIDEV_REMOVE       : u32 : 0x00000001;
RIDEV_EXCLUDE      : u32 : 0x00000010;
RIDEV_PAGEONLY     : u32 : 0x00000020;
RIDEV_NOLEGACY     : u32 : 0x00000030;
RIDEV_INPUTSINK    : u32 : 0x00000100;
RIDEV_CAPTUREMOUSE : u32 : 0x00000200;
RIDEV_NOHOTKEYS    : u32 : 0x00000200;
RIDEV_APPKEYS      : u32 : 0x00000400;
RIDEV_EXINPUTSINK  : u32 : 0x00001000;
RIDEV_DEVNOTIFY    : u32 : 0x00002000;

RAWINPUTDEVICE :: struct {
    usUsagePage : u16;
    usUsage     : u16;
    dwFlags     : u32;
    hwndTarget  : HWND;
}

RegisterRawInputDevices :: (
    pRawInputDevices : *RAWINPUTDEVICE,
    uiNumDevices     : u32,
    cbSize           : u32
) -> BOOL #foreign user32;

RIDI_PREPARSEDDATA : u32 : 0x20000005;
RIDI_DEVICENAME    : u32 : 0x20000007;
RIDI_DEVICEINFO    : u32 : 0x2000000B;

RIM_TYPEMOUSE    : u32 : 0;
RIM_TYPEKEYBOARD : u32 : 1;
RIM_TYPEHID      : u32 : 2;

MOUSE_HID_HARDWARE       : u32 : 0x0080;
WHEELMOUSE_HID_HARDWARE  : u32 : 0x0100;
HORIZONTAL_WHEEL_PRESENT : u32 : 0x8000;

RID_DEVICE_INFO_MOUSE :: struct {
    dwId                : u32;
    dwNumberOfButtons   : u32;
    dwSampleRate        : u32;
    fHasHorizontalWheel : BOOL;
}

RID_DEVICE_INFO_KEYBOARD :: struct {
    dwType                 : u32;
    dwSubType              : u32;
    dwKeyboardMode         : u32;
    dwNumberOfFunctionKeys : u32;
    dwNumberOfIndicators   : u32;
    dwNumberOfKeysTotal    : u32;
}

RID_DEVICE_INFO_HID :: struct {
    dwVendorId      : u32;
    dwProductId     : u32;
    dwVersionNumber : u32;
    usUsagePage     : u16;
    usUsage         : u16;
}

RID_DEVICE_INFO :: struct {
    cbSize : u32;
    dwType : u32;
    union {
        mouse    : RID_DEVICE_INFO_MOUSE;
        keyboard : RID_DEVICE_INFO_KEYBOARD;
        hid      : RID_DEVICE_INFO_HID;
    }
}

GetRawInputDeviceInfoW :: (
    hDevice   : HANDLE,
    uiCommand : u32,
    pData     : *void,
    pcbSize   : *u32
) -> u32 #foreign user32;

RIM_INPUT     : u8 : 0;
RIM_INPUTSINK : u8 : 1;

GET_RAWINPUT_CODE_WPARAM :: inline (wParam : WPARAM) -> u8 #no_context {
    return cast,no_check(u8) (wParam & 0xFF);
}

RAWINPUTHEADER :: struct {
    dwType  : u32;
    dwSize  : u32;
    hDevice : HANDLE;
    wParam  : WPARAM;
}

MOUSE_MOVE_RELATIVE      : u16 : 0x00;
MOUSE_MOVE_ABSOLUTE      : u16 : 0x01;
MOUSE_VIRTUAL_DESKTOP    : u16 : 0x02;
MOUSE_ATTRIBUTES_CHANGED : u16 : 0x04;
MOUSE_MOVE_NOCOALESCE    : u16 : 0x08;

RI_MOUSE_BUTTON_1_DOWN      : u16 : 0x0001;
RI_MOUSE_BUTTON_1_UP        : u16 : 0x0002;
RI_MOUSE_BUTTON_2_DOWN      : u16 : 0x0004;
RI_MOUSE_BUTTON_2_UP        : u16 : 0x0008;
RI_MOUSE_BUTTON_3_DOWN      : u16 : 0x0010;
RI_MOUSE_BUTTON_3_UP        : u16 : 0x0020;
RI_MOUSE_BUTTON_4_DOWN      : u16 : 0x0040;
RI_MOUSE_BUTTON_4_UP        : u16 : 0x0080;
RI_MOUSE_BUTTON_5_DOWN      : u16 : 0x0100;
RI_MOUSE_BUTTON_5_UP        : u16 : 0x0200;
RI_MOUSE_WHEEL              : u16 : 0x0400;
RI_MOUSE_HWHEEL             : u16 : 0x0800;
RI_MOUSE_LEFT_BUTTON_DOWN   :: RI_MOUSE_BUTTON_1_DOWN;
RI_MOUSE_LEFT_BUTTON_UP     :: RI_MOUSE_BUTTON_1_UP;
RI_MOUSE_RIGHT_BUTTON_DOWN  :: RI_MOUSE_BUTTON_2_DOWN;
RI_MOUSE_RIGHT_BUTTON_UP    :: RI_MOUSE_BUTTON_2_UP;
RI_MOUSE_MIDDLE_BUTTON_DOWN :: RI_MOUSE_BUTTON_3_DOWN;
RI_MOUSE_MIDDLE_BUTTON_UP   :: RI_MOUSE_BUTTON_3_UP;

WHEEL_DELTA : u16 : 120;

RAWMOUSE :: struct {
    usFlags : u16;
    union {
        ulButtons : u32;
        struct {
            usButtonFlags : u16;
            usButtonData  : u16;
        }
    }
    ulRawButtons       : u32;
    lLastX             : s32;
    lLastY             : s32;
    ulExtraInformation : u32;
}

KEYBOARD_OVERRUN_MAKE_CODE : u16 : 0xFF;

RI_KEY_MAKE  : u16 : 0;
RI_KEY_BREAK : u16 : 1;
RI_KEY_E0    : u16 : 2;
RI_KEY_E1    : u16 : 4;

RAWKEYBOARD :: struct {
    MakeCode         : u16;
    Flags            : u16;
    Reserved         : u16;
    VKey             : u16;
    Message          : u32;
    ExtraInformation : u32;
}

RAWHID :: struct {
    dwSizeHid : u32;
    dwCount   : u32;
    bRawData  : [1] u8;
}

RAWINPUT :: struct {
    header : RAWINPUTHEADER;
    data   : union {
        mouse    : RAWMOUSE;
        keyboard : RAWKEYBOARD;
        hid      : RAWHID;
    };
}

GetRawInputBuffer :: (
    pData        : *RAWINPUT,
    pcbSize      : *u32,
    cbSizeHeader : u32
) -> u32 #foreign user32;

RAWINPUT_ALIGN :: inline (x : *void) -> *void #no_context {
    MASK :: size_of(*void) - 1;
    return (x + MASK) & ~MASK;
}

NEXTRAWINPUTBLOCK :: inline (raw_input : *RAWINPUT) -> *RAWINPUT #no_context {
    return RAWINPUT_ALIGN(cast(*void) raw_input + raw_input.header.dwSize);
}

RID_HEADER : u32 : 0x10000005;
RID_INPUT  : u32 : 0x10000003;

GetRawInputData :: (
    hRawInput    : HRAWINPUT,
    uiCommand    : u32,
    pData        : *void,
    pcbSize      : *u32,
    cbSizeHeader : u32
) -> u32 #foreign user32;

//
// Human Interface Devices
//

HidD_GetProductString :: (
    HidDeviceObject : HANDLE,
    Buffer          : *void,
    BufferLength    : u32
) -> BOOLEAN #foreign hid;

HidD_GetManufacturerString :: (
    HidDeviceObject : HANDLE,
    Buffer          : *void,
    BufferLength    : u32
) -> BOOLEAN #foreign hid;

#scope_file

kernel32 :: #system_library "Kernel32";
user32   :: #system_library "User32";
dwmapi   :: #system_library "Dwmapi";
advapi32 :: #system_library "Advapi32";
hid      :: #system_library "Hid";
