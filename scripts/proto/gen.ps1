$ErrorActionPreference = "Stop"

$PubCacheBin = Join-Path $HOME ".pub-cache/bin"
if (Test-Path $PubCacheBin) {
  $env:PATH = "$PubCacheBin$([System.IO.Path]::PathSeparator)$env:PATH"
}

$Protoc = $env:PROTOC
if (-not $Protoc) {
  $ProtocCommand = Get-Command protoc -ErrorAction SilentlyContinue
  if (-not $ProtocCommand) {
    throw "Missing protoc. Install protobuf compiler first, or set PROTOC to the protoc binary path."
  }
  $Protoc = $ProtocCommand.Source
}

if (-not (Get-Command protoc-gen-dart -ErrorAction SilentlyContinue)) {
  throw "Missing protoc-gen-dart. Run: dart pub global activate protoc_plugin"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "../..")
$ProtoFile = Join-Path $RepoRoot "proto/ws.proto"
$ProtoDir = Join-Path $RepoRoot "proto"
$OutDir = Join-Path $RepoRoot "client/modules/flash_im_core/lib/src/data/proto"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

& $Protoc `
  --proto_path=$ProtoDir `
  --dart_out=$OutDir `
  $ProtoFile
