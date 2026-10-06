param([string]$LuaDll = (Join-Path $PSScriptRoot '../../bin/lua51.dll'))
$ErrorActionPreference = 'Stop'
$game = Get-Process -Name helldivers2 | Select-Object -First 1
$module = $game.Modules | Where-Object ModuleName -EQ 'game.dll'
$exe = $game.MainModule
if (!$module -or !$exe) { throw 'Game modules unavailable.' }
if ((Get-FileHash -LiteralPath $module.FileName).Hash -ne '2E2C3B7C2500646DADD5F2B4C6E0504DBB7E7896139F64CDDC0D1813C718F51E' -or
    (Get-FileHash -LiteralPath $exe.FileName).Hash -ne 'F5FEE03DCFDB2E553A4752C283590950AC13316B376D8196AA556FF0400D5F06') {
    throw 'Unsupported game binary.'
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class MissionLocationLuaProbe {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr LoadLibraryExW(string path, IntPtr file, uint flags);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr luaL_newstate();
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern void luaL_openlibs(IntPtr state);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern int luaL_loadbuffer(IntPtr state, byte[] source, UIntPtr length, string name);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern int lua_pcall(IntPtr state, int args, int results, int handler);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr lua_tolstring(IntPtr state, int index, out UIntPtr length);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern void lua_close(IntPtr state);
    public static void Run(string dll, string source) {
        if (LoadLibraryExW(dll, IntPtr.Zero, 8) == IntPtr.Zero) throw new Exception("Lua library unavailable.");
        var state = luaL_newstate();
        if (state == IntPtr.Zero) throw new Exception("Lua allocation failed.");
        try {
            luaL_openlibs(state);
            var bytes = Encoding.UTF8.GetBytes(source);
            int result = luaL_loadbuffer(state, bytes, (UIntPtr)bytes.Length, "@MissionLocationProbe");
            if (result == 0) result = lua_pcall(state, 0, -1, 0);
            if (result != 0) {
                UIntPtr length;
                var pointer = lua_tolstring(state, -1, out length);
                var data = new byte[(int)length.ToUInt64()];
                Marshal.Copy(pointer, data, 0, data.Length);
                throw new Exception(Encoding.UTF8.GetString(data));
            }
        } finally { lua_close(state); }
    }
}
'@
$directory = [Environment]::CurrentDirectory
try {
    [Environment]::CurrentDirectory = (Resolve-Path (Join-Path $PSScriptRoot '../stratagem')).Path
    $prefix = "local target_pid=$($game.Id); local game_base=$($module.BaseAddress.ToInt64()); local exe_base=$($exe.BaseAddress.ToInt64())`n"
    $source = $prefix + (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'mission-location-probe.lua') -Raw -Encoding UTF8)
    [MissionLocationLuaProbe]::Run((Resolve-Path -LiteralPath $LuaDll).Path, $source)
} finally { [Environment]::CurrentDirectory = $directory }
