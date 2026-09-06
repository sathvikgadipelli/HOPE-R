
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
foreach($app in @("civilian_app","government_app")){
  Push-Location (Join-Path $root $app)
  if(!(Test-Path android)){ flutter create --no-pub --platforms=android,windows . }
  flutter pub get
  Pop-Location
}
$manifest=Join-Path $root "civilian_app\android\app\src\main\AndroidManifest.xml"
if(Test-Path $manifest){
  $x=Get-Content $manifest -Raw
  if($x -notmatch "ACCESS_FINE_LOCATION"){
    $x=$x -replace '(<manifest[^>]*>)','$1`n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>`n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>'
  }
  if($x -notmatch "usesCleartextTraffic"){
    $x=$x -replace '<application','<application android:usesCleartextTraffic="true"'
  }
  Set-Content $manifest $x
}
Write-Host "HOPE-R Flutter apps ready."
