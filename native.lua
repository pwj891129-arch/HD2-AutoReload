local Native = {}

-- FFI declarations are VM-wide. Alias Win32 symbols so other mods keep their own types.
Native.declarations = [[
typedef struct { unsigned short vk, scan; unsigned int flags, time; uintptr_t extra; } HD2AR_KEY;
typedef struct { int x, y; unsigned int data, flags, time; uintptr_t extra; } HD2AR_MOUSE;
typedef union { HD2AR_KEY key; HD2AR_MOUSE mouse; } HD2AR_UNION;
typedef struct { unsigned int type; HD2AR_UNION value; } HD2AR_INPUT;
void* HD2AR_GetForegroundWindow(void) __asm__("GetForegroundWindow");
unsigned int HD2AR_GetWindowThreadProcessId(void*, unsigned int*) __asm__("GetWindowThreadProcessId");
unsigned int HD2AR_GetCurrentProcessId(void) __asm__("GetCurrentProcessId");
short HD2AR_GetAsyncKeyState(int) __asm__("GetAsyncKeyState");
unsigned int HD2AR_SendInput(unsigned int, const HD2AR_INPUT*, int) __asm__("SendInput");
unsigned int HD2AR_MapVirtualKeyW(unsigned int, unsigned int) __asm__("MapVirtualKeyW");
]]

function Native.create(ffi, config)
    ffi.cdef(Native.declarations)
    local library, kernel = ffi.load("user32"), ffi.load("kernel32")
    local user32 = {
        GetForegroundWindow = library.HD2AR_GetForegroundWindow,
        GetWindowThreadProcessId = library.HD2AR_GetWindowThreadProcessId,
        GetAsyncKeyState = library.HD2AR_GetAsyncKeyState,
        SendInput = library.HD2AR_SendInput,
    }
    local size = ffi.sizeof("HD2AR_INPUT")
    assert(size == (ffi.abi("64bit") and 40 or 28), "INPUT layout mismatch")
    local pid = ffi.new("unsigned int[1]")
    local input = ffi.new("HD2AR_INPUT[1]")
    input[0].type = 1
    local scan = library.HD2AR_MapVirtualKeyW(config.reload_vk, 4)
    assert(scan ~= 0, "reload key has no scan code")
    input[0].value.key.scan = scan % 256
    local mouse = ffi.new("HD2AR_INPUT[1]")
    mouse[0].type = 0
    mouse[0].value.mouse.flags = 4
    return { user32 = user32, process = kernel.HD2AR_GetCurrentProcessId(),
        pid = pid, input = input, mouse = mouse, size = size, flags = scan >= 256 and 9 or 8 }
end

return Native
