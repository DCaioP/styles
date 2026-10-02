# Despeja o conteudo bruto do clipboard do Windows: todos os formatos,
# tamanho real (GlobalSize) e hex dos formatos de texto.
# Uso: powershell -ExecutionPolicy Bypass -File \\tsclient\tools\clipdump.ps1 <rotulo>
# Grava tambem em clipdump-<rotulo>.txt ao lado do script.
param([string]$Rotulo = 'dump')
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Clip {
  [DllImport("user32.dll")] public static extern bool OpenClipboard(IntPtr h);
  [DllImport("user32.dll")] public static extern bool CloseClipboard();
  [DllImport("user32.dll")] public static extern uint EnumClipboardFormats(uint f);
  [DllImport("user32.dll")] public static extern IntPtr GetClipboardData(uint f);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern int GetClipboardFormatName(uint f, StringBuilder s, int n);
  [DllImport("kernel32.dll")] public static extern UIntPtr GlobalSize(IntPtr h);
  [DllImport("kernel32.dll")] public static extern IntPtr GlobalLock(IntPtr h);
  [DllImport("kernel32.dll")] public static extern bool GlobalUnlock(IntPtr h);
}
"@

$nomes = @{ 1='CF_TEXT'; 7='CF_OEMTEXT'; 13='CF_UNICODETEXT'; 16='CF_LOCALE'; 2='CF_BITMAP'; 8='CF_DIB'; 17='CF_DIBV5' }
$texto = 1, 7, 13, 16

$saida = & {
if (-not [Clip]::OpenClipboard([IntPtr]::Zero)) { throw "OpenClipboard falhou" }
try {
  $f = 0
  while (($f = [Clip]::EnumClipboardFormats($f)) -ne 0) {
    $nome = $nomes[[int]$f]
    if (-not $nome) {
      $sb = New-Object System.Text.StringBuilder 256
      [void][Clip]::GetClipboardFormatName($f, $sb, 256)
      $nome = $sb.ToString()
    }
    if ($texto -notcontains $f) { "{0,6}  {1}" -f $f, $nome; continue }

    $h = [Clip]::GetClipboardData($f)
    if ($h -eq [IntPtr]::Zero) { "{0,6}  {1}  (sem dados)" -f $f, $nome; continue }
    $size = [int][Clip]::GlobalSize($h).ToUInt64()
    $p = [Clip]::GlobalLock($h)
    $bytes = New-Object byte[] $size
    [Runtime.InteropServices.Marshal]::Copy($p, $bytes, 0, $size)
    [void][Clip]::GlobalUnlock($h)

    "{0,6}  {1}  GlobalSize={2}" -f $f, $nome, $size
    "        hex: " + (($bytes | Select-Object -First 64 | ForEach-Object { $_.ToString('X2') }) -join ' ')
  }
} finally { [void][Clip]::CloseClipboard() }
}
$saida
$saida | Out-File -Encoding utf8 (Join-Path $PSScriptRoot "clipdump-$Rotulo.txt")
