#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

#scope_export

HANDLE :: *void;

HINSTANCE :: *HINSTANCE__; HINSTANCE__ :: struct { unused : s32; }
HICON     :: *HICON__;     HICON__     :: struct { unused : s32; }
HCURSOR   :: *HCURSOR__;   HCURSOR__   :: struct { unused : s32; }
HBRUSH    :: *HBRUSH__;    HBRUSH__    :: struct { unused : s32; }
HWND      :: *HWND__;      HWND__      :: struct { unused : s32; }
HMENU     :: *HMENU__;     HMENU__     :: struct { unused : s32; }
HKEY      :: *HKEY__;      HKEY__      :: struct { unused : s32; }
HRAWINPUT :: *HRAWINPUT__; HRAWINPUT__ :: struct { unused : s32; }

HMODULE :: HINSTANCE;
HLOCAL  :: HANDLE;
HGDIOBJ :: *void;

BOOL      :: s32;
BOOLEAN   :: u8;
CHAR      :: u8;
WCHAR     :: u16;
INT_PTR   :: s64; // We target only 64-bit systems, so... whatever.
UINT_PTR  :: u64; // We target only 64-bit systems, so... whatever.
LONG_PTR  :: s64; // We target only 64-bit systems, so... whatever.
ULONG_PTR :: u64; // We target only 64-bit systems, so... whatever.
SIZE_T    :: ULONG_PTR;
DWORD_PTR :: ULONG_PTR;

PCCH    :: *CHAR;
PSTR    :: *CHAR;
PCSTR   :: *CHAR;
LPSTR   :: *CHAR;
LPCSTR  :: *CHAR;
PWSTR   :: *WCHAR;
PCWSTR  :: *WCHAR;
LPWSTR  :: *WCHAR;
LPCWSTR :: *WCHAR;

WPARAM  :: UINT_PTR;
LPARAM  :: LONG_PTR;
LRESULT :: LONG_PTR;
LSTATUS :: s32;

TRUE  : BOOL : 1;
FALSE : BOOL : 0;

ATOM :: u16;

COLORREF :: u32;

va_list :: *u8;

INVALID_HANDLE_VALUE :: cast(HANDLE) -1;

// bit 31        - 1-bit code indicating severity, where zero represents success and 1 represents failure.
// bits [30, 27] - 4-bit reserved value.
// bits [26, 16] - 11-bit code indicating responsibility for the error or warning, also known as a facility code.
// bits [15, 0]  - 16-bit code describing the result of an operation.
HRESULT :: s32;

ERROR_SUCCESS              :: 0x0000;
ERROR_FILE_NOT_FOUND       :: 0x0002;
ERROR_PATH_NOT_FOUND       :: 0x0003;
ERROR_ACCESS_DENIED        :: 0x0005;
ERROR_NO_MORE_FILES        :: 0x0012;
ERROR_SHARING_VIOLATION    :: 0x0020;
ERROR_FILE_EXISTS          :: 0x0050;
ERROR_INSUFFICIENT_BUFFER  :: 0x007A;
ERROR_MOD_NOT_FOUND        :: 0x007E;
ERROR_ALREADY_EXISTS       :: 0x00B7;
ERROR_OPERATION_ABORTED    :: 0x03E3;
ERROR_DEVICE_NOT_CONNECTED :: 0x048F;
ERROR_NOT_FOUND            :: 0x0490;
ERROR_INVALID_USER_BUFFER  :: 0x06F8;

SUCCEEDED :: inline (result : $T) -> bool {
    #assert T == u32 || T == s32 "T should be a 32-bit integer";
    return !(cast,no_check(u32) result >> 31);
}

FAILED :: inline (result : $T) -> bool {
    #assert T == u32 || T == s32 "T should be a 32-bit integer";
    return cast,no_check(u32) result >> 31;
}

// bits [31, 30] - 2-bit code indicating severity, where 0 - success, 1 - info, 2 - warning, 3 - error
// bit 29        - 1-bit customer code flag
// bits [28, 16] - 13-bit code indicating responsibility for the error or warning, also known as a facility code.
// bits [15, 0]  - 16-bit code describing the status of an operation.
NTSTATUS :: s32;

STATUS_SEVERITY_SUCCESS       : u32 : 0x0;
STATUS_SEVERITY_INFORMATIONAL : u32 : 0x1;
STATUS_SEVERITY_WARNING       : u32 : 0x2;
STATUS_SEVERITY_ERROR         : u32 : 0x3;

STATUS_SUCCESS                  : NTSTATUS : 0x0000_0000;
STATUS_PENDING                  : NTSTATUS : 0x0000_0103;
STATUS_GUARD_PAGE_VIOLATION     : NTSTATUS : 0x8000_0001;
STATUS_DATATYPE_MISALIGNMENT    : NTSTATUS : 0x8000_0002;
STATUS_BREAKPOINT               : NTSTATUS : 0x8000_0003;
STATUS_SINGLE_STEP              : NTSTATUS : 0x8000_0004;
STATUS_ACCESS_VIOLATION         : NTSTATUS : 0xC000_0005;
STATUS_IN_PAGE_ERROR            : NTSTATUS : 0xC000_0006;
STATUS_INVALID_HANDLE           : NTSTATUS : 0xC000_0008;
STATUS_ILLEGAL_INSTRUCTION      : NTSTATUS : 0xC000_001D;
STATUS_NONCONTINUABLE_EXCEPTION : NTSTATUS : 0xC000_0025;
STATUS_INVALID_DISPOSITION      : NTSTATUS : 0xC000_0026;
STATUS_ARRAY_BOUNDS_EXCEEDED    : NTSTATUS : 0xC000_008C;
STATUS_FLOAT_DENORMAL_OPERAND   : NTSTATUS : 0xC000_008D;
STATUS_FLOAT_DIVIDE_BY_ZERO     : NTSTATUS : 0xC000_008E;
STATUS_FLOAT_INEXACT_RESULT     : NTSTATUS : 0xC000_008F;
STATUS_FLOAT_INVALID_OPERATION  : NTSTATUS : 0xC000_0090;
STATUS_FLOAT_OVERFLOW           : NTSTATUS : 0xC000_0091;
STATUS_FLOAT_STACK_CHECK        : NTSTATUS : 0xC000_0092;
STATUS_FLOAT_UNDERFLOW          : NTSTATUS : 0xC000_0093;
STATUS_INTEGER_DIVIDE_BY_ZERO   : NTSTATUS : 0xC000_0094;
STATUS_INTEGER_OVERFLOW         : NTSTATUS : 0xC000_0095;
STATUS_PRIVILEGED_INSTRUCTION   : NTSTATUS : 0xC000_0096;
STATUS_STACK_OVERFLOW           : NTSTATUS : 0xC000_00FD;
STATUS_POSSIBLE_DEADLOCK        : NTSTATUS : 0xC000_0194;

STATUS_SEVERITY :: inline (status : NTSTATUS) -> u32  { return cast,no_check(u32) status >> 30; }

NT_SUCCESS     :: inline (status : NTSTATUS) -> bool { return STATUS_SEVERITY(status) == STATUS_SEVERITY_SUCCESS; }
NT_INFORMATION :: inline (status : NTSTATUS) -> bool { return STATUS_SEVERITY(status) == STATUS_SEVERITY_INFORMATIONAL; }
NT_WARNING     :: inline (status : NTSTATUS) -> bool { return STATUS_SEVERITY(status) == STATUS_SEVERITY_WARNING; }
NT_ERROR       :: inline (status : NTSTATUS) -> bool { return STATUS_SEVERITY(status) == STATUS_SEVERITY_ERROR; }

GUID :: struct {
    Data1 : u32;
    Data2 : u16;
    Data3 : u16;
    Data4 : [8] u8;
}

DUPLICATE_CLOSE_SOURCE :: 0x00000001;
DUPLICATE_SAME_ACCESS  :: 0x00000002;

DuplicateHandle :: (
    hSourceProcessHandle : HANDLE,
    hSourceHandle        : HANDLE,
    hTargetProcessHandle : HANDLE,
    lpTargetHandle       : *HANDLE,
    dwDesiredAccess      : u32,
    bInheritHandle       : BOOL,
    dwOptions            : u32
) -> BOOL #foreign kernel32;

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

GET_MODULE_HANDLE_EX_FLAG_PIN                : u32 : 1;
GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT : u32 : 2;
GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS       : u32 : 4;

GetModuleHandleExW :: (
    dwFlags      : u32,
    lpModuleName : LPCWSTR,
    phModule     : *HMODULE
) -> BOOL #foreign kernel32;

LoadLibraryA :: (
    lpLibFileName : LPCSTR
) -> HMODULE #foreign kernel32;

FreeLibrary :: (
    hLibModule : HMODULE
) -> BOOL #foreign kernel32;

FARPROC  :: #type () -> INT_PTR #c_call;
NEARPROC :: #type () -> INT_PTR #c_call;
PROC     :: #type () -> INT_PTR #c_call;

GetProcAddress :: (
    hModule    : HMODULE,
    lpProcName : LPCSTR
) -> FARPROC #foreign kernel32;

IDI_APPLICATION :: cast,no_check(LPWSTR) cast(u16) 32512;
IDI_ERROR       :: cast,no_check(LPWSTR) cast(u16) 32513;
IDI_QUESTION    :: cast,no_check(LPWSTR) cast(u16) 32514;
IDI_WARNING     :: cast,no_check(LPWSTR) cast(u16) 32515;
IDI_INFORMATION :: cast,no_check(LPWSTR) cast(u16) 32516;
IDI_WINLOGO     :: cast,no_check(LPWSTR) cast(u16) 32517;
IDI_SHIELD      :: cast,no_check(LPWSTR) cast(u16) 32518;
IDI_HAND        :: IDI_ERROR;
IDI_ASTERISK    :: IDI_INFORMATION;
IDI_EXCLAMATION :: IDI_WARNING;

LoadIconW :: (
    hInstance  : HINSTANCE,
    lpIconName : LPCWSTR
) -> HICON #foreign user32;

IDC_ARROW       :: cast,no_check(LPWSTR) cast(u16) 32512;
IDC_IBEAM       :: cast,no_check(LPWSTR) cast(u16) 32513;
IDC_WAIT        :: cast,no_check(LPWSTR) cast(u16) 32514;
IDC_CROSS       :: cast,no_check(LPWSTR) cast(u16) 32515;
IDC_UPARROW     :: cast,no_check(LPWSTR) cast(u16) 32516;
IDC_SIZE        :: cast,no_check(LPWSTR) cast(u16) 32640;
IDC_ICON        :: cast,no_check(LPWSTR) cast(u16) 32641;
IDC_SIZENWSE    :: cast,no_check(LPWSTR) cast(u16) 32642;
IDC_SIZENESW    :: cast,no_check(LPWSTR) cast(u16) 32643;
IDC_SIZEWE      :: cast,no_check(LPWSTR) cast(u16) 32644;
IDC_SIZENS      :: cast,no_check(LPWSTR) cast(u16) 32645;
IDC_SIZEALL     :: cast,no_check(LPWSTR) cast(u16) 32646;
IDC_NO          :: cast,no_check(LPWSTR) cast(u16) 32648;
IDC_HAND        :: cast,no_check(LPWSTR) cast(u16) 32649;
IDC_APPSTARTING :: cast,no_check(LPWSTR) cast(u16) 32650;
IDC_HELP        :: cast,no_check(LPWSTR) cast(u16) 32651;

LoadCursorW :: (
    hInstance    : HINSTANCE,
    lpCursorName : LPCWSTR
) -> HCURSOR #foreign user32;

GWL_STYLE   : s32 : -16;
GWL_EXSTYLE : s32 : -20;

GetWindowLongW :: (
    hWnd   : HWND,
    nIndex : s32
) -> s32 #foreign user32;

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

WM :: enum u32 #specified {
    WM_NULL                           :: 0x0000;
    WM_CREATE                         :: 0x0001;
    WM_DESTROY                        :: 0x0002;
    WM_MOVE                           :: 0x0003;
    WM_SIZE                           :: 0x0005;
    WM_ACTIVATE                       :: 0x0006;
    WM_SETFOCUS                       :: 0x0007;
    WM_KILLFOCUS                      :: 0x0008;
    WM_ENABLE                         :: 0x000A;
    WM_SETREDRAW                      :: 0x000B;
    WM_SETTEXT                        :: 0x000C;
    WM_GETTEXT                        :: 0x000D;
    WM_GETTEXTLENGTH                  :: 0x000E;
    WM_PAINT                          :: 0x000F;
    WM_CLOSE                          :: 0x0010;
    WM_QUERYENDSESSION                :: 0x0011;
    WM_QUERYOPEN                      :: 0x0013;
    WM_ENDSESSION                     :: 0x0016;
    WM_QUIT                           :: 0x0012;
    WM_ERASEBKGND                     :: 0x0014;
    WM_SYSCOLORCHANGE                 :: 0x0015;
    WM_SHOWWINDOW                     :: 0x0018;
    WM_SETTINGCHANGE                  :: 0x001A;
    WM_DEVMODECHANGE                  :: 0x001B;
    WM_ACTIVATEAPP                    :: 0x001C;
    WM_FONTCHANGE                     :: 0x001D;
    WM_TIMECHANGE                     :: 0x001E;
    WM_CANCELMODE                     :: 0x001F;
    WM_SETCURSOR                      :: 0x0020;
    WM_MOUSEACTIVATE                  :: 0x0021;
    WM_CHILDACTIVATE                  :: 0x0022;
    WM_QUEUESYNC                      :: 0x0023;
    WM_GETMINMAXINFO                  :: 0x0024;
    WM_PAINTICON                      :: 0x0026;
    WM_ICONERASEBKGND                 :: 0x0027;
    WM_NEXTDLGCTL                     :: 0x0028;
    WM_SPOOLERSTATUS                  :: 0x002A;
    WM_DRAWITEM                       :: 0x002B;
    WM_MEASUREITEM                    :: 0x002C;
    WM_DELETEITEM                     :: 0x002D;
    WM_VKEYTOITEM                     :: 0x002E;
    WM_CHARTOITEM                     :: 0x002F;
    WM_SETFONT                        :: 0x0030;
    WM_GETFONT                        :: 0x0031;
    WM_SETHOTKEY                      :: 0x0032;
    WM_GETHOTKEY                      :: 0x0033;
    WM_QUERYDRAGICON                  :: 0x0037;
    WM_COMPAREITEM                    :: 0x0039;
    WM_GETOBJECT                      :: 0x003D;
    WM_COMPACTING                     :: 0x0041;
    WM_COMMNOTIFY                     :: 0x0044; // no longer suported
    WM_WINDOWPOSCHANGING              :: 0x0046;
    WM_WINDOWPOSCHANGED               :: 0x0047;
    WM_POWER                          :: 0x0048;
    WM_COPYDATA                       :: 0x004A;
    WM_CANCELJOURNAL                  :: 0x004B;
    WM_NOTIFY                         :: 0x004E;
    WM_INPUTLANGCHANGEREQUEST         :: 0x0050;
    WM_INPUTLANGCHANGE                :: 0x0051;
    WM_TCARD                          :: 0x0052;
    WM_HELP                           :: 0x0053;
    WM_USERCHANGED                    :: 0x0054;
    WM_NOTIFYFORMAT                   :: 0x0055;
    WM_CONTEXTMENU                    :: 0x007B;
    WM_STYLECHANGING                  :: 0x007C;
    WM_STYLECHANGED                   :: 0x007D;
    WM_DISPLAYCHANGE                  :: 0x007E;
    WM_GETICON                        :: 0x007F;
    WM_SETICON                        :: 0x0080;
    WM_NCCREATE                       :: 0x0081;
    WM_NCDESTROY                      :: 0x0082;
    WM_NCCALCSIZE                     :: 0x0083;
    WM_NCHITTEST                      :: 0x0084;
    WM_NCPAINT                        :: 0x0085;
    WM_NCACTIVATE                     :: 0x0086;
    WM_GETDLGCODE                     :: 0x0087;
    WM_SYNCPAINT                      :: 0x0088;
    WM_NCMOUSEMOVE                    :: 0x00A0;
    WM_NCLBUTTONDOWN                  :: 0x00A1;
    WM_NCLBUTTONUP                    :: 0x00A2;
    WM_NCLBUTTONDBLCLK                :: 0x00A3;
    WM_NCRBUTTONDOWN                  :: 0x00A4;
    WM_NCRBUTTONUP                    :: 0x00A5;
    WM_NCRBUTTONDBLCLK                :: 0x00A6;
    WM_NCMBUTTONDOWN                  :: 0x00A7;
    WM_NCMBUTTONUP                    :: 0x00A8;
    WM_NCMBUTTONDBLCLK                :: 0x00A9;
    WM_NCXBUTTONDOWN                  :: 0x00AB;
    WM_NCXBUTTONUP                    :: 0x00AC;
    WM_NCXBUTTONDBLCLK                :: 0x00AD;
    WM_INPUT_DEVICE_CHANGE            :: 0x00FE;
    WM_INPUT                          :: 0x00FF;
    WM_KEYFIRST                       :: 0x0100;
    WM_KEYDOWN                        :: 0x0100;
    WM_KEYUP                          :: 0x0101;
    WM_CHAR                           :: 0x0102;
    WM_DEADCHAR                       :: 0x0103;
    WM_SYSKEYDOWN                     :: 0x0104;
    WM_SYSKEYUP                       :: 0x0105;
    WM_SYSCHAR                        :: 0x0106;
    WM_SYSDEADCHAR                    :: 0x0107;
    WM_UNICHAR                        :: 0x0109;
    WM_KEYLAST                        :: 0x0109;
    WM_IME_STARTCOMPOSITION           :: 0x010D;
    WM_IME_ENDCOMPOSITION             :: 0x010E;
    WM_IME_COMPOSITION                :: 0x010F;
    WM_IME_KEYLAST                    :: 0x010F;
    WM_INITDIALOG                     :: 0x0110;
    WM_COMMAND                        :: 0x0111;
    WM_SYSCOMMAND                     :: 0x0112;
    WM_TIMER                          :: 0x0113;
    WM_HSCROLL                        :: 0x0114;
    WM_VSCROLL                        :: 0x0115;
    WM_INITMENU                       :: 0x0116;
    WM_INITMENUPOPUP                  :: 0x0117;
    WM_GESTURE                        :: 0x0119;
    WM_GESTURENOTIFY                  :: 0x011A;
    WM_MENUSELECT                     :: 0x011F;
    WM_MENUCHAR                       :: 0x0120;
    WM_ENTERIDLE                      :: 0x0121;
    WM_MENURBUTTONUP                  :: 0x0122;
    WM_MENUDRAG                       :: 0x0123;
    WM_MENUGETOBJECT                  :: 0x0124;
    WM_UNINITMENUPOPUP                :: 0x0125;
    WM_MENUCOMMAND                    :: 0x0126;
    WM_CHANGEUISTATE                  :: 0x0127;
    WM_UPDATEUISTATE                  :: 0x0128;
    WM_QUERYUISTATE                   :: 0x0129;
    WM_CTLCOLORMSGBOX                 :: 0x0132;
    WM_CTLCOLOREDIT                   :: 0x0133;
    WM_CTLCOLORLISTBOX                :: 0x0134;
    WM_CTLCOLORBTN                    :: 0x0135;
    WM_CTLCOLORDLG                    :: 0x0136;
    WM_CTLCOLORSCROLLBAR              :: 0x0137;
    WM_CTLCOLORSTATIC                 :: 0x0138;
    MN_GETHMENU                       :: 0x01E1;
    WM_MOUSEFIRST                     :: 0x0200;
    WM_MOUSEMOVE                      :: 0x0200;
    WM_LBUTTONDOWN                    :: 0x0201;
    WM_LBUTTONUP                      :: 0x0202;
    WM_LBUTTONDBLCLK                  :: 0x0203;
    WM_RBUTTONDOWN                    :: 0x0204;
    WM_RBUTTONUP                      :: 0x0205;
    WM_RBUTTONDBLCLK                  :: 0x0206;
    WM_MBUTTONDOWN                    :: 0x0207;
    WM_MBUTTONUP                      :: 0x0208;
    WM_MBUTTONDBLCLK                  :: 0x0209;
    WM_MOUSEWHEEL                     :: 0x020A;
    WM_XBUTTONDOWN                    :: 0x020B;
    WM_XBUTTONUP                      :: 0x020C;
    WM_XBUTTONDBLCLK                  :: 0x020D;
    WM_MOUSEHWHEEL                    :: 0x020E;
    WM_MOUSELAST                      :: 0x020E;
    WM_PARENTNOTIFY                   :: 0x0210;
    WM_ENTERMENULOOP                  :: 0x0211;
    WM_EXITMENULOOP                   :: 0x0212;
    WM_NEXTMENU                       :: 0x0213;
    WM_SIZING                         :: 0x0214;
    WM_CAPTURECHANGED                 :: 0x0215;
    WM_MOVING                         :: 0x0216;
    WM_POWERBROADCAST                 :: 0x0218;
    WM_DEVICECHANGE                   :: 0x0219;
    WM_MDICREATE                      :: 0x0220;
    WM_MDIDESTROY                     :: 0x0221;
    WM_MDIACTIVATE                    :: 0x0222;
    WM_MDIRESTORE                     :: 0x0223;
    WM_MDINEXT                        :: 0x0224;
    WM_MDIMAXIMIZE                    :: 0x0225;
    WM_MDITILE                        :: 0x0226;
    WM_MDICASCADE                     :: 0x0227;
    WM_MDIICONARRANGE                 :: 0x0228;
    WM_MDIGETACTIVE                   :: 0x0229;
    WM_MDISETMENU                     :: 0x0230;
    WM_ENTERSIZEMOVE                  :: 0x0231;
    WM_EXITSIZEMOVE                   :: 0x0232;
    WM_DROPFILES                      :: 0x0233;
    WM_MDIREFRESHMENU                 :: 0x0234;
    WM_POINTERDEVICECHANGE            :: 0x0238;
    WM_POINTERDEVICEINRANGE           :: 0x0239;
    WM_POINTERDEVICEOUTOFRANGE        :: 0x023A;
    WM_TOUCH                          :: 0x0240;
    WM_NCPOINTERUPDATE                :: 0x0241;
    WM_NCPOINTERDOWN                  :: 0x0242;
    WM_NCPOINTERUP                    :: 0x0243;
    WM_POINTERUPDATE                  :: 0x0245;
    WM_POINTERDOWN                    :: 0x0246;
    WM_POINTERUP                      :: 0x0247;
    WM_POINTERENTER                   :: 0x0249;
    WM_POINTERLEAVE                   :: 0x024A;
    WM_POINTERACTIVATE                :: 0x024B;
    WM_POINTERCAPTURECHANGED          :: 0x024C;
    WM_TOUCHHITTESTING                :: 0x024D;
    WM_POINTERWHEEL                   :: 0x024E;
    WM_POINTERHWHEEL                  :: 0x024F;
    DM_POINTERHITTEST                 :: 0x0250;
    WM_POINTERROUTEDTO                :: 0x0251;
    WM_POINTERROUTEDAWAY              :: 0x0252;
    WM_POINTERROUTEDRELEASED          :: 0x0253;
    WM_IME_SETCONTEXT                 :: 0x0281;
    WM_IME_NOTIFY                     :: 0x0282;
    WM_IME_CONTROL                    :: 0x0283;
    WM_IME_COMPOSITIONFULL            :: 0x0284;
    WM_IME_SELECT                     :: 0x0285;
    WM_IME_CHAR                       :: 0x0286;
    WM_IME_REQUEST                    :: 0x0288;
    WM_IME_KEYDOWN                    :: 0x0290;
    WM_IME_KEYUP                      :: 0x0291;
    WM_MOUSEHOVER                     :: 0x02A1;
    WM_MOUSELEAVE                     :: 0x02A3;
    WM_NCMOUSEHOVER                   :: 0x02A0;
    WM_NCMOUSELEAVE                   :: 0x02A2;
    WM_WTSSESSION_CHANGE              :: 0x02B1;
    WM_TABLET_FIRST                   :: 0x02C0;
    WM_TABLET_LAST                    :: 0x02DF;
    WM_DPICHANGED                     :: 0x02E0;
    WM_DPICHANGED_BEFOREPARENT        :: 0x02E2;
    WM_DPICHANGED_AFTERPARENT         :: 0x02E3;
    WM_GETDPISCALEDSIZE               :: 0x02E4;
    WM_CUT                            :: 0x0300;
    WM_COPY                           :: 0x0301;
    WM_PASTE                          :: 0x0302;
    WM_CLEAR                          :: 0x0303;
    WM_UNDO                           :: 0x0304;
    WM_RENDERFORMAT                   :: 0x0305;
    WM_RENDERALLFORMATS               :: 0x0306;
    WM_DESTROYCLIPBOARD               :: 0x0307;
    WM_DRAWCLIPBOARD                  :: 0x0308;
    WM_PAINTCLIPBOARD                 :: 0x0309;
    WM_VSCROLLCLIPBOARD               :: 0x030A;
    WM_SIZECLIPBOARD                  :: 0x030B;
    WM_ASKCBFORMATNAME                :: 0x030C;
    WM_CHANGECBCHAIN                  :: 0x030D;
    WM_HSCROLLCLIPBOARD               :: 0x030E;
    WM_QUERYNEWPALETTE                :: 0x030F;
    WM_PALETTEISCHANGING              :: 0x0310;
    WM_PALETTECHANGED                 :: 0x0311;
    WM_HOTKEY                         :: 0x0312;
    WM_PRINT                          :: 0x0317;
    WM_PRINTCLIENT                    :: 0x0318;
    WM_APPCOMMAND                     :: 0x0319;
    WM_THEMECHANGED                   :: 0x031A;
    WM_CLIPBOARDUPDATE                :: 0x031D;
    WM_DWMCOMPOSITIONCHANGED          :: 0x031E;
    WM_DWMNCRENDERINGCHANGED          :: 0x031F;
    WM_DWMCOLORIZATIONCOLORCHANGED    :: 0x0320;
    WM_DWMWINDOWMAXIMIZEDCHANGE       :: 0x0321;
    WM_DWMSENDICONICTHUMBNAIL         :: 0x0323;
    WM_DWMSENDICONICLIVEPREVIEWBITMAP :: 0x0326;
    WM_GETTITLEBARINFOEX              :: 0x033F;
    WM_HANDHELDFIRST                  :: 0x0358;
    WM_HANDHELDLAST                   :: 0x035F;
    WM_AFXFIRST                       :: 0x0360;
    WM_AFXLAST                        :: 0x037F;
    WM_PENWINFIRST                    :: 0x0380;
    WM_PENWINLAST                     :: 0x038F;
    WM_APP                            :: 0x8000;
    /*
     * NOTE: All Message Numbers below 0x0400 are RESERVED.
     *
     * Private Window Messages Start Here:
     */
    WM_USER                           :: 0x0400;
}

DefWindowProcW :: (
    hWnd   : HWND,
    Msg    : WM,
    wParam : WPARAM,
    lParam : LPARAM
) -> LRESULT #foreign user32;

SC :: enum u32 #specified {
    SC_SIZE         :: 0xF000;
    SC_MOVE         :: 0xF010;
    SC_MINIMIZE     :: 0xF020;
    SC_MAXIMIZE     :: 0xF030;
    SC_NEXTWINDOW   :: 0xF040;
    SC_PREVWINDOW   :: 0xF050;
    SC_CLOSE        :: 0xF060;
    SC_VSCROLL      :: 0xF070;
    SC_HSCROLL      :: 0xF080;
    SC_MOUSEMENU    :: 0xF090;
    SC_KEYMENU      :: 0xF100;
    SC_ARRANGE      :: 0xF110;
    SC_RESTORE      :: 0xF120;
    SC_TASKLIST     :: 0xF130;
    SC_SCREENSAVE   :: 0xF140;
    SC_HOTKEY       :: 0xF150;
    SC_DEFAULT      :: 0xF160;
    SC_MONITORPOWER :: 0xF170;
    SC_CONTEXTHELP  :: 0xF180;
    SC_SEPARATOR    :: 0xF00F;

    SCF_ISSECURE    :: 0x00000001;
}

// The only supported system colors since Windows 10
COLOR_WINDOW        : s32 : 5;
COLOR_WINDOWTEXT    : s32 : 8;
COLOR_HIGHLIGHT     : s32 : 13;
COLOR_HIGHLIGHTTEXT : s32 : 14;
COLOR_3DFACE        : s32 : 15;
COLOR_GRAYTEXT      : s32 : 17;
COLOR_BTNTEXT       : s32 : 18;
COLOR_HOTLIGHT      : s32 : 26;

CreateSolidBrush :: (
    color : COLORREF
) -> HBRUSH #foreign gdi32;

GetLastError :: (
) -> u32 #foreign kernel32;

EXCEPTION :: enum u32 #specified {
    GUARD_PAGE               :: 0x8000_0001; // STATUS_GUARD_PAGE_VIOLATION
    DATATYPE_MISALIGNMENT    :: 0x8000_0002; // STATUS_DATATYPE_MISALIGNMENT
    BREAKPOINT               :: 0x8000_0003; // STATUS_BREAKPOINT
    SINGLE_STEP              :: 0x8000_0004; // STATUS_SINGLE_STEP
    ACCESS_VIOLATION         :: 0xC000_0005; // STATUS_ACCESS_VIOLATION
    IN_PAGE_ERROR            :: 0xC000_0006; // STATUS_IN_PAGE_ERROR
    INVALID_HANDLE           :: 0xC000_0008; // STATUS_INVALID_HANDLE
    ILLEGAL_INSTRUCTION      :: 0xC000_001D; // STATUS_ILLEGAL_INSTRUCTION
    NONCONTINUABLE_EXCEPTION :: 0xC000_0025; // STATUS_NONCONTINUABLE_EXCEPTION
    INVALID_DISPOSITION      :: 0xC000_0026; // STATUS_INVALID_DISPOSITION
    ARRAY_BOUNDS_EXCEEDED    :: 0xC000_008C; // STATUS_ARRAY_BOUNDS_EXCEEDED
    FLT_DENORMAL_OPERAND     :: 0xC000_008D; // STATUS_FLOAT_DENORMAL_OPERAND
    FLT_DIVIDE_BY_ZERO       :: 0xC000_008E; // STATUS_FLOAT_DIVIDE_BY_ZERO
    FLT_INEXACT_RESULT       :: 0xC000_008F; // STATUS_FLOAT_INEXACT_RESULT
    FLT_INVALID_OPERATION    :: 0xC000_0090; // STATUS_FLOAT_INVALID_OPERATION
    FLT_OVERFLOW             :: 0xC000_0091; // STATUS_FLOAT_OVERFLOW
    FLT_STACK_CHECK          :: 0xC000_0092; // STATUS_FLOAT_STACK_CHECK
    FLT_UNDERFLOW            :: 0xC000_0093; // STATUS_FLOAT_UNDERFLOW
    INT_DIVIDE_BY_ZERO       :: 0xC000_0094; // STATUS_INTEGER_DIVIDE_BY_ZERO
    INT_OVERFLOW             :: 0xC000_0095; // STATUS_INTEGER_OVERFLOW
    PRIV_INSTRUCTION         :: 0xC000_0096; // STATUS_PRIVILEGED_INSTRUCTION
    STACK_OVERFLOW           :: 0xC000_00FD; // STATUS_STACK_OVERFLOW
    POSSIBLE_DEADLOCK        :: 0xC000_0194; // STATUS_POSSIBLE_DEADLOCK
}

EXCEPTION_MAXIMUM_PARAMETERS :: 15;

EXCEPTION_RECORD :: struct {
    ExceptionCode        : EXCEPTION;
    ExceptionFlags       : u32;
    ExceptionRecord      : *EXCEPTION_RECORD;
    ExceptionAddress     : *void;
    NumberParameters     : u32;
    ExceptionInformation : [EXCEPTION_MAXIMUM_PARAMETERS] ULONG_PTR;
}

M128A :: struct {
    Low  : u64;
    High : s64;
}

XSAVE_FORMAT :: struct {
    ControlWord    : u16;
    StatusWord     : u16;
    TagWord        : u8;
    Reserved1      : u8;
    ErrorOpcode    : u16;
    ErrorOffset    : u32;
    ErrorSelector  : u16;
    Reserved2      : u16;
    DataOffset     : u32;
    DataSelector   : u16;
    Reserved3      : u16;
    MxCsr          : u32;
    MxCsr_Mask     : u32;
    FloatRegisters : [8] M128A #align 16;
    #if CPU == .X64 {
        XmmRegisters : [16] M128A #align 16;
        Reserved4    : [96] u8;
    } else {
        XmmRegisters : [8]   M128A #align 16;
        Reserved4    : [224] u8;
    }
}

XMM_SAVE_AREA32 :: XSAVE_FORMAT;

NEON128 :: struct {
    Low  : u64;
    High : s64;
}

CONTEXT :: struct {
    P1Home       : u64;
    P2Home       : u64;
    P3Home       : u64;
    P4Home       : u64;
    P5Home       : u64;
    P6Home       : u64;
    ContextFlags : u32;
    MxCsr        : u32;
    SegCs        : u16;
    SegDs        : u16;
    SegEs        : u16;
    SegFs        : u16;
    SegGs        : u16;
    SegSs        : u16;
    EFlags       : u32;
    Dr0          : u64;
    Dr1          : u64;
    Dr2          : u64;
    Dr3          : u64;
    Dr6          : u64;
    Dr7          : u64;
    Rax          : u64;
    Rcx          : u64;
    Rdx          : u64;
    Rbx          : u64;
    Rsp          : u64;
    Rbp          : u64;
    Rsi          : u64;
    Rdi          : u64;
    R8           : u64;
    R9           : u64;
    R10          : u64;
    R11          : u64;
    R12          : u64;
    R13          : u64;
    R14          : u64;
    R15          : u64;
    Rip          : u64;
    union {
        FltSave : XMM_SAVE_AREA32 #align 16;
        Q       : [16] NEON128;
        D       : [32] u64;
        struct {
            Header : [2] M128A #align 16;
            Legacy : [8] M128A #align 16;
            Xmm0   : M128A     #align 16;
            Xmm1   : M128A     #align 16;
            Xmm2   : M128A     #align 16;
            Xmm3   : M128A     #align 16;
            Xmm4   : M128A     #align 16;
            Xmm5   : M128A     #align 16;
            Xmm6   : M128A     #align 16;
            Xmm7   : M128A     #align 16;
            Xmm8   : M128A     #align 16;
            Xmm9   : M128A     #align 16;
            Xmm10  : M128A     #align 16;
            Xmm11  : M128A     #align 16;
            Xmm12  : M128A     #align 16;
            Xmm13  : M128A     #align 16;
            Xmm14  : M128A     #align 16;
            Xmm15  : M128A     #align 16;
        }
        S : [32] u32;
    }
    VectorRegister       : [26] M128A #align 16;
    VectorControl        : u64;
    DebugControl         : u64;
    LastBranchToRip      : u64;
    LastBranchFromRip    : u64;
    LastExceptionToRip   : u64;
    LastExceptionFromRip : u64;
}

EXCEPTION_POINTERS :: struct {
    ExceptionRecord : *EXCEPTION_RECORD;
    ContextRecord   : *CONTEXT #align 16;
}

EXCEPTION_CONTINUE_EXECUTION : s32 : -1;
EXCEPTION_CONTINUE_SEARCH    : s32 :  0;
EXCEPTION_EXECUTE_HANDLER    : s32 :  1;

TOP_LEVEL_EXCEPTION_FILTER :: #type (
    ExceptionInfo : *EXCEPTION_POINTERS
) -> s32 #c_call;

SetUnhandledExceptionFilter :: (
    lpTopLevelExceptionFilter : TOP_LEVEL_EXCEPTION_FILTER
) -> TOP_LEVEL_EXCEPTION_FILTER #foreign kernel32;

FORMAT_MESSAGE_ALLOCATE_BUFFER : u32 : 0x00000100;
FORMAT_MESSAGE_IGNORE_INSERTS  : u32 : 0x00000200;
FORMAT_MESSAGE_FROM_SYSTEM     : u32 : 0x00001000;

LANG_NEUTRAL       : u16 : 0x00;
LANG_ENGLISH       : u16 : 0x09;

SUBLANG_DEFAULT    : u16 : 0x01; // user default
SUBLANG_ENGLISH_US : u16 : 0x01; // English (USA)

MAKELANGID :: inline (primary_language : u16, secondary_language : u16) -> u16 {
    return (secondary_language << 10) | primary_language;
}

FormatMessageA :: (
    dwFlags      : u32,
    lpSource     : *void,
    dwMessageId  : u32,
    dwLanguageId : u32,
    lpBuffer     : LPSTR,
    nSize        : u32,
    Arguments    : *va_list
) -> u32 #foreign kernel32;

RtlUTF8ToUnicodeN :: (
    UnicodeStringDestination     : PWSTR,
    UnicodeStringMaxByteCount    : u32,
    UnicodeStringActualByteCount : *u32,
    UTF8StringSource             : PCCH,
    UTF8StringByteCount          : u32
) -> NTSTATUS #foreign ntdll;

RtlUnicodeToUTF8N :: (
    UTF8StringDestination     : *CHAR,
    UTF8StringMaxByteCount    : u32,
    UTF8StringActualByteCount : *u32,
    UnicodeStringSource       : PCWSTR,
    UnicodeStringByteCount    : u32
) -> NTSTATUS #foreign ntdll;

PostQuitMessage :: (
    nExitCode : s32
) #foreign user32;

WINDOWPOS :: struct {
    hwnd            : HWND;
    hwndInsertAfter : HWND;
    x               : s32;
    y               : s32;
    cx              : s32;
    cy              : s32;
    flags           : u32;
}

RECT :: struct {
    left   : s32;
    top    : s32;
    right  : s32;
    bottom : s32;
}

SWP_NOSIZE         : u32 : 0x0001;
SWP_NOMOVE         : u32 : 0x0002;
SWP_NOZORDER       : u32 : 0x0004;
SWP_NOACTIVATE     : u32 : 0x0010;
SWP_SHOWWINDOW     : u32 : 0x0040;
SWP_NOOWNERZORDER  : u32 : 0x0200;
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

MINMAXINFO :: struct {
    ptReserved     : POINT;
    ptMaxSize      : POINT;
    ptMaxPosition  : POINT;
    ptMinTrackSize : POINT;
    ptMaxTrackSize : POINT;
}

GetCurrentProcess :: (
) -> HANDLE #foreign kernel32;

SIZE_MINIMIZED : u32 : 1;
SIZE_MAXIMIZED : u32 : 2;

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

DestroyWindow :: (
    hWnd : HWND
) -> BOOL #foreign user32;

AdjustWindowRectEx :: (
    lpRect    : *RECT,
    dwStyle   : u32,
    bMenu     : BOOL,
    dwExStyle : u32
) -> BOOL #foreign user32;

GetDpiForWindow :: (
    hwnd : HWND
) -> u32 #foreign user32;

POINT :: struct {
    x : s32;
    y : s32;
}

MSG :: struct {
    hwnd     : HWND;
    message  : WM;
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
    wMsgFilterMin : WM,
    wMsgFilterMax : WM,
    wRemoveMsg    : u32
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

GetWindowTextLengthW :: (
    hWnd : HWND
) -> s32 #foreign user32;

GetWindowTextW :: (
    hWnd      : HWND,
    lpString  : LPWSTR,
    nMaxCount : s32
) -> s32 #foreign user32;

SetWindowTextW :: (
    hWnd     : HWND,
    lpString : LPCWSTR
) -> BOOL #foreign user32;

//
// Memory
//

MEM_COMMIT      : u32 : 0x00001000;
MEM_RESERVE     : u32 : 0x00002000;
MEM_DECOMMIT    : u32 : 0x00004000;
MEM_LARGE_PAGES : u32 : 0x20000000;
MEM_64K_PAGES   : u32 : 0x20400000;

PAGE_READWRITE : u32 : 0x04;

VirtualAlloc :: (
    lpAddress        : *void,
    dwSize           : SIZE_T,
    flAllocationType : u32,
    flProtect        : u32
) -> *void #foreign kernel32;

MEM_EXTENDED_PARAMETER_TYPE_BITS :: 8;

MEM_EXTENDED_PARAMETER_TYPE :: enum u32 {
    MemExtendedParameterInvalidType :: 0;
    MemExtendedParameterAddressRequirements;
    MemExtendedParameterNumaNode;
    MemExtendedParameterPartitionHandle;
    MemExtendedParameterUserPhysicalHandle;
    MemExtendedParameterAttributeFlags;
    MemExtendedParameterImageMachine;
    MemExtendedParameterMax;
}

MEM_ADDRESS_REQUIREMENTS :: struct {
    LowestStartingAddress : *void;
    HighestEndingAddress  : *void;
    Alignment             : SIZE_T;
}

MEM_EXTENDED_PARAMETER :: struct {
    Type : u64;
    union {
        ULong64 : u64;
        Pointer : *void;
        Size    : SIZE_T;
        Handle  : HANDLE;
        ULong   : u32;
    }
}

VirtualAlloc2 :: (
    Process            : HANDLE,
    BaseAddress        : *void,
    Size               : SIZE_T,
    AllocationType     : u32,
    PageProtection     : u32,
    ExtendedParameters : *MEM_EXTENDED_PARAMETER,
    ParameterCount     : u32
) -> *void #foreign onecore;

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

GetNativeSystemInfo :: (
    lpSystemInfo : *SYSTEM_INFO
) -> void #foreign kernel32;

IsDebuggerPresent :: (
) -> BOOL #foreign kernel32;

GetCommandLineA :: (
) -> LPSTR #foreign kernel32;

ATTACH_PARENT_PROCESS : u32 : 0xFFFF_FFFF;

AttachConsole :: (
    dwProcessId : u32
) -> BOOL #foreign kernel32;

AllocConsole :: (
) -> BOOL #foreign kernel32;

FreeConsole :: (
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

//
// Thread
//

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

//
// Sync
//

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

//
// IO
//

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
INVALID_FILE_ATTRIBUTES              : u32 : 0xFFFFFFFF;

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

FILE_BEGIN   :: 0;
FILE_CURRENT :: 1;
FILE_END     :: 2;

SetFilePointerEx :: (
    hFile            : HANDLE,
    liDistanceToMove : LARGE_INTEGER,
    lpNewFilePointer : *LARGE_INTEGER,
    dwMoveMethod     : u32
) -> BOOL #foreign kernel32;

FlushFileBuffers :: (
    hFile : HANDLE
) -> BOOL #foreign kernel32;

GetOverlappedResult :: (
    hFile                      : HANDLE,
    lpOverlapped               : *OVERLAPPED,
    lpNumberOfBytesTransferred : *u32,
    bWait                      : BOOL
) -> BOOL #foreign kernel32;

HasOverlappedIoCompleted :: inline (lpOverlapped : *OVERLAPPED) -> bool #no_context {
    return cast(s32) lpOverlapped.Internal != STATUS_PENDING;
}

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

GetFileAttributesW :: (
    lpFileName : LPCWSTR
) -> u32 #foreign kernel32;

BY_HANDLE_FILE_INFORMATION :: struct {
    dwFileAttributes     : u32;
    ftCreationTime       : FILETIME;
    ftLastAccessTime     : FILETIME;
    ftLastWriteTime      : FILETIME;
    dwVolumeSerialNumber : u32;
    nFileSizeHigh        : u32;
    nFileSizeLow         : u32;
    nNumberOfLinks       : u32;
    nFileIndexHigh       : u32;
    nFileIndexLow        : u32;
}

GetFileInformationByHandle :: (
    hFile             : HANDLE,
    lpFileInformation : *BY_HANDLE_FILE_INFORMATION
) -> BOOL #foreign kernel32;

FILE_INFO_BY_HANDLE_CLASS :: enum s32 {
    FileBasicInfo;
    FileStandardInfo;
    FileNameInfo;
    FileRenameInfo;
    FileDispositionInfo;
    FileAllocationInfo;
    FileEndOfFileInfo;
    FileStreamInfo;
    FileCompressionInfo;
    FileAttributeTagInfo;
    FileIdBothDirectoryInfo;
    FileIdBothDirectoryRestartInfo;
    FileIoPriorityHintInfo;
    FileRemoteProtocolInfo;
    FileFullDirectoryInfo;
    FileFullDirectoryRestartInfo;
    FileStorageInfo;
    FileAlignmentInfo;
    FileIdInfo;
    FileIdExtdDirectoryInfo;
    FileIdExtdDirectoryRestartInfo;
    FileDispositionInfoEx;
    FileRenameInfoEx;
    FileCaseSensitiveInfo;
    FileNormalizedNameInfo;
    MaximumFileInfoByHandleClass;
}

FILE_NAME_INFO :: struct {
    FileNameLength : u32;
    FileName       : [1] WCHAR;
}

FILE_ATTRIBUTE_TAG_INFO :: struct {
    FileAttributes : u32;
    ReparseTag     : u32;
}

GetFileInformationByHandleEx :: (
    hFile                : HANDLE,
    FileInformationClass : FILE_INFO_BY_HANDLE_CLASS,
    lpFileInformation    : *void,
    dwBufferSize         : u32
) -> BOOL #foreign kernel32;

GetFullPathNameW :: (
    lpFileName    : LPCWSTR,
    nBufferLength : u32,
    lpBuffer      : LPWSTR,
    lpFilePart    : *LPWSTR
) -> u32 #foreign kernel32;

//
// Sync API
//

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

CRITICAL_SECTION :: struct {
    DebugInfo      : *void;
    LockCount      : s32;
    RecursionCount : s32;
    OwningThread   : HANDLE;
    LockSemaphore  : HANDLE;
    SpinCount      : ULONG_PTR;
}

InitializeCriticalSection :: (
    lpCriticalSection : *CRITICAL_SECTION
) #foreign kernel32;

DeleteCriticalSection :: (
    lpCriticalSection : *CRITICAL_SECTION
) #foreign kernel32;

EnterCriticalSection :: (
    lpCriticalSection : *CRITICAL_SECTION
) #foreign kernel32;

LeaveCriticalSection :: (
    lpCriticalSection : *CRITICAL_SECTION
) #foreign kernel32;

TryEnterCriticalSection :: (
    lpCriticalSection : *CRITICAL_SECTION
) -> BOOL #foreign kernel32;

//
// Input
//

VK :: enum u8 #specified {
    BACK             :: 0x08;
    TAB              :: 0x09;

    RETURN           :: 0x0D;
    ESCAPE           :: 0x1B;
    SPACE            :: 0x20;

    CAPITAL          :: 0x14;
    NUMLOCK          :: 0x90;
    SCROLL           :: 0x91;

    PRIOR            :: 0x21; // Page Up
    NEXT             :: 0x22; // Page Down
    END              :: 0x23;
    HOME             :: 0x24;
    INSERT           :: 0x2D;
    DELETE           :: 0x2E;

    LEFT             :: 0x25;
    UP               :: 0x26;
    RIGHT            :: 0x27;
    DOWN             :: 0x28;

    NUMPAD0          :: 0x60;
    NUMPAD1          :: 0x61;
    NUMPAD2          :: 0x62;
    NUMPAD3          :: 0x63;
    NUMPAD4          :: 0x64;
    NUMPAD5          :: 0x65;
    NUMPAD6          :: 0x66;
    NUMPAD7          :: 0x67;
    NUMPAD8          :: 0x68;
    NUMPAD9          :: 0x69;
    DIVIDE           :: 0x6F;
    MULTIPLY         :: 0x6A;
    SUBTRACT         :: 0x6D;
    ADD              :: 0x6B;
// There is no NUM_ENTER
    DECIMAL          :: 0x6E;

    F1               :: 0x70;
    F2               :: 0x71;
    F3               :: 0x72;
    F4               :: 0x73;
    F5               :: 0x74;
    F6               :: 0x75;
    F7               :: 0x76;
    F8               :: 0x77;
    F9               :: 0x78;
    F10              :: 0x79;
    F11              :: 0x7A;
    F12              :: 0x7B;
    F13              :: 0x7C;
    F14              :: 0x7D;
    F15              :: 0x7E;
    F16              :: 0x7F;
    F17              :: 0x80;
    F18              :: 0x81;
    F19              :: 0x82;
    F20              :: 0x83;
    F21              :: 0x84;
    F22              :: 0x85;
    F23              :: 0x86;
    F24              :: 0x87;

    _0               :: #char "0";
    _1               :: #char "1";
    _2               :: #char "2";
    _3               :: #char "3";
    _4               :: #char "4";
    _5               :: #char "5";
    _6               :: #char "6";
    _7               :: #char "7";
    _8               :: #char "8";
    _9               :: #char "9";

    A                :: #char "A";
    B                :: #char "B";
    C                :: #char "C";
    D                :: #char "D";
    E                :: #char "E";
    F                :: #char "F";
    G                :: #char "G";
    H                :: #char "H";
    I                :: #char "I";
    J                :: #char "J";
    K                :: #char "K";
    L                :: #char "L";
    M                :: #char "M";
    N                :: #char "N";
    O                :: #char "O";
    P                :: #char "P";
    Q                :: #char "Q";
    R                :: #char "R";
    S                :: #char "S";
    T                :: #char "T";
    U                :: #char "U";
    V                :: #char "V";
    W                :: #char "W";
    X                :: #char "X";
    Y                :: #char "Y";
    Z                :: #char "Z";

    SHIFT            :: 0x10; // Left or right shift
    CONTROL          :: 0x11; // Left or right ctrl
    MENU             :: 0x12; // Left or right alt

    LSHIFT           :: 0xA0;
    RSHIFT           :: 0xA1;
    LCONTROL         :: 0xA2;
    RCONTROL         :: 0xA3;
    LMENU            :: 0xA4; // Left alt
    RMENU            :: 0xA5; // Right alt
    LWIN             :: 0x5B;
    RWIN             :: 0x5C;
    APPS             :: 0x5D; // Context menu key

    OEM_COMMA        :: 0xBC; // ,<
    OEM_PERIOD       :: 0xBE; // .>
    OEM_2            :: 0xBF; // /?
    OEM_1            :: 0xBA; // ;:
    OEM_7            :: 0xDE; // '"
    OEM_5            :: 0xDC; // \|
    OEM_4            :: 0xDB; // [{
    OEM_6            :: 0xDD; // ]}
    OEM_MINUS        :: 0xBD; // -_
    OEM_PLUS         :: 0xBB; // =+
    OEM_3            :: 0xC0; // `~

    VOLUME_MUTE      :: 0xAD;
    VOLUME_DOWN      :: 0xAE;
    VOLUME_UP        :: 0xAF;

    MEDIA_PREV_TRACK :: 0xB1;
    MEDIA_NEXT_TRACK :: 0xB0;
    MEDIA_PLAY_PAUSE :: 0xB3;
    MEDIA_STOP       :: 0xB2;

    OEM_102          :: 0xE2; // "<>" or "\|" on RT 102-key kbd.

    PRINT            :: 0x2A;
    CANCEL           :: 0x03; // Break
    PAUSE            :: 0x13;
}

GetKeyState :: (
    nVirtKey : s32
) -> s16 #foreign user32;

GetCursorPos :: (
    lpPoint : *POINT
) -> BOOL #foreign user32;

SM_CXSCREEN : s32 : 0;
SM_CYSCREEN : s32 : 1;

GetSystemMetrics :: (
    nIndex : s32
) -> s32 #foreign user32;

//
// Raw input
//

GIDC_ARRIVAL : u8 : 1;
GIDC_REMOVAL : u8 : 2;

GET_DEVICE_CHANGE_WPARAM :: inline (wparam : WPARAM) -> u8 #no_context {
    return cast(u8) (wparam & 0xFF);
}

HID_USAGE_PAGE :: enum u16 #specified {
    UNDEFINED :: 0x0000;
    GENERIC   :: 0x0001;
    // We don't need any other
    VENDOR_DEFINED_BEGIN :: 0xFF00;
    VENDOR_DEFINED_END   :: 0xFFFF;
}

HID_USAGE :: enum u16 #specified {
    GENERIC_MOUSE    :: 0x02;
    GENERIC_KEYBOARD :: 0x06;
    // We don't need any other
}

RIDEV :: enum_flags u32 #specified {
    REMOVE       :: 0x00000001;
    EXCLUDE      :: 0x00000010;
    PAGEONLY     :: 0x00000020;
    NOLEGACY     :: 0x00000030;
    INPUTSINK    :: 0x00000100;
    CAPTUREMOUSE :: 0x00000200;
    NOHOTKEYS    :: 0x00000200;
    APPKEYS      :: 0x00000400;
    EXINPUTSINK  :: 0x00001000;
    DEVNOTIFY    :: 0x00002000;
}

RAWINPUTDEVICE :: struct {
    usUsagePage : HID_USAGE_PAGE;
    usUsage     : HID_USAGE;
    dwFlags     : RIDEV;
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

RIM :: enum u32 #specified {
    TYPEMOUSE    :: 0;
    TYPEKEYBOARD :: 1;
    TYPEHID      :: 2;
}

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
    usUsagePage     : HID_USAGE_PAGE;
    usUsage         : HID_USAGE;
}

RID_DEVICE_INFO :: struct {
    cbSize : u32;
    dwType : RIM;
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
    dwType  : RIM;
    dwSize  : u32;
    hDevice : HANDLE;
    wParam  : WPARAM;
}

MOUSE :: enum_flags u16 #specified {
    MOVE_RELATIVE      :: 0x00;
    MOVE_ABSOLUTE      :: 0x01;
    VIRTUAL_DESKTOP    :: 0x02;
    ATTRIBUTES_CHANGED :: 0x04;
    MOVE_NOCOALESCE    :: 0x08;
}

RI_MOUSE :: enum_flags u16 #specified {
    BUTTON_1_DOWN      :: 0x0001;
    BUTTON_1_UP        :: 0x0002;
    BUTTON_2_DOWN      :: 0x0004;
    BUTTON_2_UP        :: 0x0008;
    BUTTON_3_DOWN      :: 0x0010;
    BUTTON_3_UP        :: 0x0020;
    BUTTON_4_DOWN      :: 0x0040;
    BUTTON_4_UP        :: 0x0080;
    BUTTON_5_DOWN      :: 0x0100;
    BUTTON_5_UP        :: 0x0200;
    WHEEL              :: 0x0400;
    HWHEEL             :: 0x0800;
    LEFT_BUTTON_DOWN   :: BUTTON_1_DOWN;
    LEFT_BUTTON_UP     :: BUTTON_1_UP;
    RIGHT_BUTTON_DOWN  :: BUTTON_2_DOWN;
    RIGHT_BUTTON_UP    :: BUTTON_2_UP;
    MIDDLE_BUTTON_DOWN :: BUTTON_3_DOWN;
    MIDDLE_BUTTON_UP   :: BUTTON_3_UP;
}

WHEEL_DELTA : u16 : 120;

RAWMOUSE :: struct {
    usFlags : MOUSE;
    union {
        ulButtons : u32;
        struct {
            usButtonFlags : RI_MOUSE;
            usButtonData  : u16;
        }
    }
    ulRawButtons       : u32;
    lLastX             : s32;
    lLastY             : s32;
    ulExtraInformation : u32;
}

KEYBOARD_OVERRUN_MAKE_CODE : u16 : 0xFF;

RI :: enum_flags u16 #specified {
    KEY_MAKE  :: 0;
    KEY_BREAK :: 1;
    KEY_E0    :: 2;
    KEY_E1    :: 4;
}

RAWKEYBOARD :: struct {
    MakeCode         : u16;
    Flags            : RI;
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

RAWINPUT_ALIGNMENT      :: size_of(*void);
RAWINPUT_ALIGNMENT_MASK :: RAWINPUT_ALIGNMENT - 1;

RAWINPUT_ALIGN :: inline (x : *void) -> *void #no_context {
    return (x + RAWINPUT_ALIGNMENT_MASK) & ~RAWINPUT_ALIGNMENT_MASK;
}

NEXTRAWINPUTBLOCK :: inline (raw_input : *RAWINPUT) -> *RAWINPUT {
    assert(!(raw_input & RAWINPUT_ALIGNMENT_MASK), "raw_input should be aligned to RAWINPUT_ALIGNMENT (%)", RAWINPUT_ALIGNMENT);
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
// HID
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

//
// XInput
//

XINPUT_GAMEPAD_DPAD_UP        :: 0x0001;
XINPUT_GAMEPAD_DPAD_DOWN      :: 0x0002;
XINPUT_GAMEPAD_DPAD_LEFT      :: 0x0004;
XINPUT_GAMEPAD_DPAD_RIGHT     :: 0x0008;
XINPUT_GAMEPAD_START          :: 0x0010;
XINPUT_GAMEPAD_BACK           :: 0x0020;
XINPUT_GAMEPAD_LEFT_THUMB     :: 0x0040;
XINPUT_GAMEPAD_RIGHT_THUMB    :: 0x0080;
XINPUT_GAMEPAD_LEFT_SHOULDER  :: 0x0100;
XINPUT_GAMEPAD_RIGHT_SHOULDER :: 0x0200;
XINPUT_GAMEPAD_A              :: 0x1000;
XINPUT_GAMEPAD_B              :: 0x2000;
XINPUT_GAMEPAD_X              :: 0x4000;
XINPUT_GAMEPAD_Y              :: 0x8000;

XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE  :: 7849;
XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE :: 8689;
XINPUT_GAMEPAD_TRIGGER_THRESHOLD    :: 30;

XINPUT_GAMEPAD :: struct {
    wButtons      : u16;
    bLeftTrigger  : u8;
    bRightTrigger : u8;
    sThumbLX      : s16;
    sThumbLY      : s16;
    sThumbRX      : s16;
    sThumbRY      : s16;
}

XINPUT_STATE :: struct {
    dwPacketNumber : u32;
    Gamepad        : XINPUT_GAMEPAD;
}

PFN_XInputGetState :: #type (
    dwUserIndex : u32,
    pState      : *XINPUT_STATE
) -> u32 #c_call;

//
// Stack trace
//

RtlCaptureStackBackTrace :: (
    FramesToSkip    : u32,
    FramesToCapture : u32,
    BackTrace       : **void,
    BackTraceHash   : *u32
) -> u16 #foreign ntdll;

SymInitialize :: (
    hProcess       : HANDLE,
    UserSearchPath : PCSTR,
    fInvadeProcess : BOOL
) -> BOOL #foreign dbghelp;

SymCleanup :: (
    hProcess : HANDLE
) -> BOOL #foreign dbghelp;

IMAGEHLP_LINE64 :: struct {
    SizeOfStruct : u32;
    Key          : *void;
    LineNumber   : u32;
    FileName     : *CHAR;
    Address      : u64;
}

SymGetLineFromAddr64 :: (
    hProcess        : HANDLE,
    qwAddr          : u64,
    pdwDisplacement : *u32,
    Line64          : *IMAGEHLP_LINE64
) -> BOOL #foreign dbghelp;

SYM_TYPE :: enum s32 {
    SymNone :: 0;
    SymCoff;
    SymCv;
    SymPdb;
    SymExport;
    SymDeferred;
    SymSym;
    SymDia;
    SymVirtual;
    NumSymType;
}

IMAGEHLP_MODULE64 :: struct {
    SizeOfStruct    : u32;
    BaseOfImage     : u64;
    ImageSize       : u32;
    TimeDateStamp   : u32;
    CheckSum        : u32;
    NumSyms         : u32;
    SymType         : SYM_TYPE;
    ModuleName      : [32]  CHAR;
    ImageName       : [256] CHAR;
    LoadedImageName : [256] CHAR;
    LoadedPdbName   : [256] CHAR;
    CVSig           : u32;
    CVData          : [MAX_PATH * 3] CHAR;
    PdbSig          : u32;
    PdbSig70        : GUID;
    PdbAge          : u32;
    PdbUnmatched    : BOOL;
    DbgUnmatched    : BOOL;
    LineNumbers     : BOOL;
    GlobalSymbols   : BOOL;
    TypeInfo        : BOOL;
    SourceIndexed   : BOOL;
    Publics         : BOOL;
    MachineType     : u32;
    Reserved        : u32;
}

SymGetModuleInfo64 :: (
    hProcess   : HANDLE,
    qwAddr     : u64,
    ModuleInfo : *IMAGEHLP_MODULE64
) -> BOOL #foreign dbghelp;

MAX_SYM_NAME :: 2000;

SYMBOL_INFO :: struct {
    SizeOfStruct : u32;
    TypeIndex    : u32;
    Reserved     : [2] u64;
    Index        : u32;
    Size         : u32;
    ModBase      : u64;
    Flags        : u32;
    Value        : u64;
    Address      : u64;
    Register     : u32;
    Scope        : u32;
    Tag          : u32;
    NameLen      : u32;
    MaxNameLen   : u32;
    Name         : [1] CHAR;
}

SymFromAddr :: (
    hProcess     : HANDLE,
    Address      : u64,
    Displacement : *u64,
    Symbol       : *SYMBOL_INFO
) -> BOOL #foreign dbghelp;

#scope_file

kernel32 :: #library,system "kernel32";
user32   :: #library,system "user32";
dwmapi   :: #library,system "dwmapi";
advapi32 :: #library,system "advapi32";
hid      :: #library,system "hid";
ntdll    :: #library,system "ntdll";
dbghelp  :: #library,system "dbghelp";
onecore  :: #library,system,no_dll "onecore";
gdi32    :: #library,system "gdi32";
