# BGPSInfo
Similiar to BGInfo, except in PowerShell. Utilizes an XML file with embedded PowerShell for background layout.
BGPSInfo is my attempt to replace BGInfo with something customizable. Powershell was chosen to accomplish this. The script has only had limited testing so far. Use at your own risk.

## Parameters
### BaseImageLocation
The path to an image to use as the "real" background. The image that shows beneath the overlay. If this is not set, the script will attempt to randomly select one of window's default images. This overrides the background from an information file.
### NoBaseBG
If set, the script will not enforce a background for the overlay and will suppress backgrounds specified in the Information file.
### SavePath
Location to save the created image. Default = "C:\Windows\Temp\BGPSInfo.jpg"
### InformationPath
Path to an answer file of sorts. Allows you to customize the layout the script generates by editing an XML file.

## Usage
Inside of a powershell console enter the following:
```
BGPSInfo.ps1 -BaseImageLocation <Path to base image> -SavePath <Full path to save the new wallpaper at> -InformationFile <Path to answer file>
```
Example:
```
&"C:\Scripts\Get-Hash.ps1" -InformationFile "C:\AnswerFile.xml"
```
## Notes
-This script will not update resolution and monitor information if you re-run the script in the same session. If you run the script in a PowerShell session, change your resolution, then re-run the script, it will generate the background incorrectly. You must start the script in another session. This is not normally an issue in real-world scenarios as you are more than likely going to use a method to trigger the script which will run it in a new session every time. This is only relevant when testing the script.
-There are many built-in defaults to try and catch potential issues. Most issues should be silently handled by the script, but may lead to unexpected results. If you run the script manually you can see the warnings it throws. There is even more detail located in a log it creates at "C:\Windows\Temp\BGPSInfo.ps1.log". If you change the name of the script, the log file name will change accordingly.
-Since the XML file can have PowerShell embedded into it, it's best to place it in a location where users only have read access.

## Value Snippets
These are some snippets of PowerShell for the value elements in the XML file.

### Current MachineName
```
<Value>return $env:COMPUTERNAME</Value>
```
### Current Username
```
<Value>return $env:USERNAME</Value>
```
### User Domain
```
<Value>return $env:USERDOMAIN</Value>
```
### IP Address
```
<Value>return (Get-NetIPAddress -InterfaceAlias "Ethernet").IPAddress</Value>
```
###
```
<Value>return (Get-CimInstance Win32_OperatingSystem).Caption.Replace("Microsoft","")</Value>
```
###
```
<Value>return (Get-CimInstance Win32_OperatingSystem).ServicePackMajorVersion+"."+(Get-CimInstance Win32_OperatingSystem).ServicePackMinorVersion</Value>
```
###
```
<Value>return (Get-CimInstance Win32_ComputerSystem).Manufacturer</Value>
```
