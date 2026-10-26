param([string]$Godot=$env:GODOT)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
  foreach($name in @('godot4','godot')) {
    $cmd=Get-Command $name -ErrorAction SilentlyContinue
    if($cmd) { $Godot=$cmd.Source; break }
  }
}
if (-not $Godot) {
  $files=Get-ChildItem "$env:LOCALAPPDATA/Programs/Godot" -Filter '*console.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
  if($files) { $Godot=$files[0].FullName }
}
if(-not $Godot) { throw 'Godot not found. Use -Godot with the Godot 4 console executable path.' }
$tests=@('test_exploration.gd','test_free_gameplay.gd','test_exploration_loop.gd','test_pixel_ui.gd','test_visual_assets_v06.gd','test_touch_ui.gd','test_road_profile.gd','test_reference_layout.gd','test_performance_budget.gd','test_resource_cycle.gd','test_reference_combat.gd','test_resource_interruptions.gd','test_seven_day_resources.gd')
function Invoke-GodotChecked([string[]]$RunArgs) {
  $output = & $Godot @RunArgs 2>&1
  $code = $LASTEXITCODE
  $output | ForEach-Object { Write-Host $_ }
  if(($output -join "`n") -match 'SCRIPT ERROR:|Parse Error:|FAIL:') { throw 'Godot reported a script/test error.' }
  if($code -ne 0) { throw 'Godot check failed.' }
}
Invoke-GodotChecked -RunArgs @('--headless','--editor','--path',$project,'--import')
foreach($test in $tests) {
  Write-Host "Running $test"
  Invoke-GodotChecked -RunArgs @('--headless','--path',$project,'--script',"tests/$test")
}
