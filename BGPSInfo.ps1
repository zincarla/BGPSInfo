<#
.SYNOPSIS
    Changes the desktop background and includes an information overlay.
 
.DESCRIPTION
    This script is intended to be edited to customize an informational overlay on the desktop background
 
.PARAMETER BaseImageLocation
    The path to an image to use as the "real" background. The image that shows beneath the overlay. If this is not set, the script will attempt to randomly select one of window's default images. This overrides the background from an information file.
 
.PARAMETER NoBaseBG
    If set, the script will not enforce a background for the overlay and will suppress backgrounds specified in the Information file.
 
.PARAMETER SavePath
    Location to save the created image. Default = "C:\Windows\Temp\BGPSInfo.jpg"
 
.PARAMETER InformationPath
    Path to an answer file of sorts. Allows you to customize the layout the script generates, by editing an XML file.
 
.NOTES
    Version:        1.3
    Author:         Matthew Thompson
    Creation Date:  2015-04-08
    Purpose/Change: Features, Value Offset, ValueJustification in list
 
    Version:        1.2
    Author:         Matthew Thompson
    Creation Date:  2015-04-06
    Purpose/Change: Bug fixes, ListValue align feature added, InformationOffset feature added.
 
    Version:        1.1
    Author:         Matthew Thompson
    Creation Date:  2015-04-05
    Purpose/Change: Bug fixes, features.
 
    Version:        1.0
    Author:         Matthew Thompson
    Creation Date:  2015-04-04
    Purpose/Change: Initial script development
 
    This script needs to be run in a new session whenever the resolution changes. Not sure why but [System.Windows.Forms.Screen]::AllScreens does not update with resolution/monitor changes. This generally won't be an issue unless you are trying to test the script. Real-world use is likely going to be run once at logon, then that session ends.
 
.EXAMPLE
    BGPSInfo.ps1 -BaseImageLocation "C:\Pictures\Wallpaper.jpg" -SavePath "C:\Users\Public\wallpaper.jpg"
 
.EXAMPLE
    BSPSInfo.ps1
#>
Param
(
    $BaseImageLocation, #TODO: Customize default BaseImageLocation.
    [switch]$NoBaseBG,
    $SavePath="C:\Windows\Temp\BGPSInfo.jpg", #TODO: Customize default save location
    $InformationPath #TODO: Customize default InformationPath
)
 
$ErrorActionPreference = "SilentlyContinue"
 
#Log File Info
$ScriptName = Split-Path -Leaf $PSCommandPath
$LogFile = Join-Path -Path "C:\Windows\Temp" -ChildPath ($ScriptName+".log")
(Get-Help -Name $PSCommandPath -Full).alertset.alert.Text -match "^\s*Version\s*:\s*[\w\d\.\,]*" | Out-Null
if ($matches-ne$null-and$matches.Count-ge1)
{
    $Version = $matches[0] -replace "^\s*Version\s*:\s*",""
}
 
#Add some required assemblies. Forms for interacting the screen information. Drawing to generate the background.
Add-Type -AssemblyName "System.Windows.Forms"
Add-Type -AssemblyName "System.Drawing"
 
#region Function Declaration
 
<#
.SYNOPSIS
    Writes a message to the log and optionally to another output as well.
 
.PARAMETER Append
    Appends the information to an existing log
 
.PARAMETER Error
    Calls Write-Error as well. Note that the stack trace will be incorrect!
 
.PARAMETER Warning
    Calls Write-Warning as well
 
.PARAMETER WriteOut
    Calls Write-Output as well
 
.PARAMETER Message
    The message to log and optionally write
 
.PARAMETER Component
    Component that called this function. Helps in troubleshooting and adds some order to the log file.
#>
function Write-Log
{
    Param
    (
        [switch]$Append=$true,
        [switch]$Error,
        [switch]$Warning,
        [switch]$WriteOut,
        [String]$Message,
        [String]$Component
    )
    $EventDate = [DateTime]::Now.ToString("s")
    $Message=($EventDate+" : ["+$Component+"] "+$Message.Replace("`r"," ").Replace("`n"," "))
    $Message | Out-File $Script:LogFile -Append:$Append
    if ($Error)
    {
        Write-Error $Message
    }
    elseif($Warning)
    {
        Write-Warning $Message
    }
    elseif($WriteOut)
    {
        Write-Output $Message
    }
 
}
 
<#
.SYNOPSIS
    Sets the desktop background.
 
.PARAMETER Path
    Path to the wallpaper image.
#>
function Set-Wallpaper
{
    param(
        [Parameter(Mandatory=$true)]
        $Path
    )
    #Add C# code to easily communicate with system APIs
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32;
namespace Wallpaper
{
    public class Setter
    {
        public const int SetDesktopWallpaper = 20;
        public const int UpdateIniFile = 0x01;
        public const int SendWinIniChange = 0x02;
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);
        public static void SetWallpaper ( string path ) 
        {
            SystemParametersInfo( SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange );
        }
    }
}
"@
    #Set registry keys for a non-tiling spanning desktop
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value 22
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value 0
    #Run the C# code to set the wallpaper and refresh the desktop. This had to be done in C#. Attempts to use rundll did not work.
    [Wallpaper.Setter]::SetWallpaper($Path) 
}
 
<#
.SYNOPSIS
    Returns an image encoder.
 
.DESCRIPTION
    Returns an image encoder. If the requested encoder is not found, the function will call itself to find image/jpeg. If that is not found, null is returned instead.
 
.PARAMETER MimeType
    The MimeType of the desired Encoder 'image/jpeg', 'image/bmp', etc
 
.PARAMETER DontLoop
    Call this to prevent the function from calling itself. (Function already sets this, after it's first attempt to find an alternate encoder, to prevent stack overflow)
#>
function Get-Encoder
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$MimeType,
        [switch]$DontLoop
    )
    $Encoders = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()
    foreach($Encoder in $Encoders)
    {
        if ($Encoder.MimeType -eq $MimeType)
        {
            return $Encoder
        }
    }
 
    if ($DontLoop)
    {
        Write-Log -Warning -Message "Could not find image encoder for ($MimeType). Further attempts prevented." -Component "Get-Encoder" -Append
        return $null
    }
    else
    {
        Write-Log -Warning -Message "Could not find image encoder for ($MimeType)." -Component "Get-Encoder" -Append
        #if we could not find the requested Encoder, call the function again for a default of jpeg. Use DontLoop to prevent an infinite loop leading to stackoverflow.
        return Get-Encoder -MimeType "image/jpeg" -DontLoop
    }
}
 
<#
.SYNOPSIS
    Restrains an interger to be between two values.
 
.PARAMETER Value
    Value to restrain
 
.PARAMETER Min
    Min possible Value
 
.PARAMETER Max
    Max possible Value
 
.PARAMETER Default
    Default to return if we get a null
 
.PARAMETER Name
    Name for logging. (Helps in debugging)
#>
function Restrain-Int
{
    Param
    (
        $Value,
        [Parameter(Mandatory=$true)]
        $Min,
        [Parameter(Mandatory=$true)]
        $Max,
        $Default,
        [string]$Name
    )
    #If our value is null
    if ($Value -eq $null)
    {
        #Write a warning and return the default if present, if not, use the min
        Write-Log -Message ("Value ($Value) of $Name was null. Used default ($Default).") -Component "Restrain-Int" -Warning -Append
        if ($Default -ne $null)
        {
            return $Default
        }
        else
        {
            return $Min
        }
    }
    #If the value is a string, trim any white space to prevent int conversion issues
    if ($Value.GetType().Name -eq "String")
    {
        $Value=$Value.Trim()
    }
    try
    {
        #Try to convert the value to an int
        $Value=[int]$Value
    }
    catch
    {
        #If we failed, return the default if present, or min
        Write-Log -Message ("Value ($Value) of $Name could not be converted to an int. Default used. "+$_.ToString()) -Component "Restrain-Int" -Warning -Append
        if ($Default -ne $null)
        {
            return $Default
        }
        else
        {
            return $Min
        }
    }
    #if value is less that our minimum boundary, write a warning and set value to min
    if ($Value -lt $Min)
    {
        Write-Log -Message ("Value ($Value) of $Name was too small and had to be restrained. Limit crossed: $Min") -Component "Restrain-Int" -Warning -Append
        return $Min
    }
    #if value is greated than our max boundary, return the max and write a warning
    if ($Value -gt $Max)
    {
        Write-Log -Message ("Value ($Value) of $Name was too large and had to be restrained. Limit crossed: $Max") -Component "Restrain-Int" -Warning -Append
        return $Max
    }
    #If there is nothing wrong with the value, return it.
    return $Value
}
 
#region Graphics Helpers
<#
.SYNOPSIS
    Handles drawing lists so you don't have to.
 
.PARAMETER $List
    List of objects to list. Should be in format of @(@{Name="asdf",Value="asdf"})
 
.PARAMETER NameBrush
    Brush to use when drawing the item name
 
.PARAMETER NameFont
    Font to use for the item names
 
.PARAMETER ValueBrush
    Brush to use for the item values
 
.PARAMETER ValueFont
    Font to use for the item values
 
.PARAMETER Width
    Width of the list
 
.PARAMETER X
    X Location of the upper left corner of the list
 
.PARAMETER Y
    Y Location of the upper left corner of the list
 
.PARAMETER Graphics
    Graphics object to user when drawing the list.
 
.PARAMETER EstimateOnly
    Does not draw the list. Only estimates the total height.
 
.PARAMETER ValueJustification
    "Left" or "Right". Sets the alginment of values.
 
.PARAMTER ValueOffset
    Anchor point and offset amount for the values. (Ex. "Left 50" or "Right 0" or "Left")
 
.OUTPUTS
    Returns the list height so you can organize things under the list.
 
.EXAMPLE
    DrawList -List @(@{Name="IP", Value="::1"},@{Name="User",Value="John.Doe"}) -NameBrush $NameBrush -NameFont $NameFont -ValueBrush $ValueBrush -ValueFont $ValueFont -Width 200 -X 0 -Y 0 -Graphics $Graphics
#>
function DrawList
{
    Param
    (
        [Parameter(Mandatory=$true)]
        $List,
        [Parameter(Mandatory=$true)]
        $NameBrush,
        [Parameter(Mandatory=$true)]
        $NameFont,
        [Parameter(Mandatory=$true)]
        $ValueBrush,
        [Parameter(Mandatory=$true)]
        $ValueFont,
        [Parameter(Mandatory=$true)]
        $Width,
        [Parameter(Mandatory=$true)]
        $X,
        [Parameter(Mandatory=$true)]
        $Y,
        [Parameter(Mandatory=$true)]
        $Graphics,
        $ValueJustification="Left",
        $ValueOffset="Right",
        [switch]
        $EstimateOnly
    )
    #Sanitize the Justification and offset inputs
    #Trim to remove any new lines from XML
    if ($ValueJustification -ne $null)
    {
        $ValueJustification = $ValueJustification.Trim()
    }
    if ($ValueOffset-ne $null)
    {
        $ValueOffset = $ValueOffset.Trim()
    }
    #If not set or not set in a recognizable way, set a default
    if (-not $ValueJustification -or ($ValueJustification -ne "Left" -and $ValueJustification -ne "Right"))
    {
        $ValueJustification = "Left"
        Write-Log -Message "Justification not set in list. Defaulting to 'Left'" -Append -Component "Draw-List"
    }
    if (-not $ValueOffset)
    {
        $ValueOffset = "Right"
        Write-Log -Message "ValueOffset not set in list. Defaulting to 'Right'" -Append -Component "Draw-List"
    }
    $ValueOffsetAmount=$null #null represents auto offset to names or right edge
    if ($ValueOffset.Split(" ", [StringSplitOptions]::RemoveEmptyEntries).Length -eq 2)
    {
        $ValueOffsetAmount = Restrain-Int -Value $ValueOffset.Split(" ", [StringSplitOptions]::RemoveEmptyEntries)[1] -Min 0 -Max $Width -Default $null -Name "ValueOffsetAmount"
        $ValueOffset = $ValueOffset.Split(" ", [StringSplitOptions]::RemoveEmptyEntries)[0]
    }
    elseif ($ValueOffset -ne "Left" -and $ValueOffset -ne "Right")
    {
        $ValueOffset = "Right"
        Write-Log -Message "ValueOffset not a recognized value. Defaulting to 'Right'" -Append -Component "Draw-List"
    }
 
    $YOffset = $Y #Used to return the delta of the offset
 
    #This part is used to justify things later
    $MaxValueWidth =0 #Maximum width of the values
    $MaxNameWidth =0 #Maximum width of the Names
 
    if ($ValueOffset -eq "Left" -or $ValueJustification -eq "Left")
    {
        foreach($Item in $List)
        {
            #Estimate widths to find longest value
            $VSize = $Graphics.MeasureString($Item.Value, $ValueFont)
            if ($VSize.Width -gt $MaxValueWidth)
            {
                $MaxValueWidth = $VSize.Width
            }
        }
    }
 
    if ($ValueOffsetAmount -eq $null -and $ValueOffset -eq "Left")
    {
        foreach($Item in $List)
        {
            #Estimate widths to find longest value
            $NSize = $Graphics.MeasureString($Item.Name, $NameFont)
            if ($NSize.Width -gt $MaxNameWidth)
            {
                $MaxNameWidth = $NSize.Width
            }
        }
    }
 
    #For every item in the list to draw
    foreach($Item in $List)
    {
        #Get the size of the name
        $NSize = $Graphics.MeasureString($Item.Name+":", $NameFont)
        if (-not $EstimateOnly)
        {
            #If we are not getting the size, then draw the Name
            $Graphics.DrawString($Item.Name+":", $NameFont, $NameBrush, $X, $YOffset);
        }
 
        #Get the size of the Value
        $VSize = $Graphics.MeasureString($Item.Value, $ValueFont)
        if (-not $EstimateOnly)
        {
            #If we are not getting the size, then draw the value
 
            #Get a value to offset based on justification setting
            $JustificationOffset = 0
 
            if ($ValueJustification -eq "Right")
            {
                $JustificationOffset = -$VSize.Width
            }
            else
            {
                #Assume Left
                $JustificationOffset = -$MaxValueWidth
            }
 
            #Adjust offset according to user settings
            if ($ValueOffsetAmount-ne $null)
            {
                #Direction mod changes the affect of the entered offset amount. Since positive always shift right, we need to multiple by negative 1 to shift objects left when anchor is right.
                $DirectionMod = 1
                if ($ValueOffset -eq "Right")
                {
                    $DirectionMod=-1
                }
                $JustificationOffset = $JustificationOffset + ($DirectionMod*$ValueOffsetAmount)
            }
            if ($ValueOffset -ne "Right")
            {
                #Assume Left
                $JustificationOffset = -$Width +$MaxNameWidth+$JustificationOffset+$MaxValueWidth
            }
            $Graphics.DrawString($Item.Value, $ValueFont, $ValueBrush, $X+$Width+$JustificationOffset, $YOffset);
        }
        #The name or value could be larger height-wise. Add the largest one to the Y offset to prevent overlapping with other elements
        if ($NSize.Height -gt $VSize.Height)
        {
            $YOffset+=$NSize.Height
        }
        else
        {
            $YOffset+=$VSize.Height
        }
    }
    #Return the change in y offset.
    return $YOffset-$Y
}
<#
.SYNOPSIS
    Retrieves a graphics tool from the DrawingTools array.
 
.DESCRIPTION
    Retrieves a graphics tool from the DrawingTools array. If it is unable to locate the requested tool, it will resplace it with the specified default.
 
.PARAMETER RefName
    Name of the graphics tool
 
.PARAMETER DrawingTools
    The array of drawing tools to use.
 
.PARAMETER Default
    Name of the default tool to return if we cannot find the requested tool
#>
function Get-GraphicsTool
{
    Param
    (
        $RefName,
        [Parameter(Mandatory=$true)]
        $DrawingTools,
        [Parameter(Mandatory=$true)]
        $Default
    )
    #Correct any potential issues with the refname
    if ($RefName -ne $null)
    {
        $RefName = $RefName.Trim()
    }
    if ($RefName -ne $null -and $DrawingTools.ContainsKey($RefName))
    {
        #return the tool if it exists
        return $DrawingTools[$RefName]
    }
    else
    {
        #If it does not, write a warning, and return the default
        Write-Log -Message ("GraphicsTool ("+$Item.FontRefName+") not set, or could not be loaded. Using the default.") -Component "Get-GraphicsTool" -Warning -Append
        return $DrawingTools[$Default]
    }
}
<#
.SYNOPSIS
    Draws an overlay based on an XMLNode
 
.DESCRIPTION
    Draws an overlay based on an XMLNode
 
.PARAMETER ItemsXMLNode
    The ItemsXML Node.
 
.PARAMETER DrawingTools
    The array of drawing tools to use.
 
.PARAMETER Graphics
    Graphics object to use when rendering
 
.PARAMETER XOffset
    X offset of where to draw the information
 
.PARAMETER YOffset
    Y Offset of where to draw the information
 
.PARAMETER Width
    Width of the list.
 
.PARAMETER MeasureOnly
    Does not actually draw any information. Only returns the calculated height of what would have been drawn.
#>
function Draw-Information
{
    Param
    (
        [Parameter(Mandatory=$true)]
        $ItemsXMLNode,
        [Parameter(Mandatory=$true)]
        $DrawingTools,
        [Parameter(Mandatory=$true)]
        [System.Drawing.Graphics]$Graphics,
        $XOffset=0,
        $YOffset=0,
        $Width=300,
        [switch]$MeasureOnly
    )
    #Used to return a delta
    $OrigYOffset = $YOffset
    if ($MeasureOnly)
    {
        Write-Log -Message "Measure Only set." -Append -Component "Draw-Information"
    }
    else
    {
        Write-Log -Message "Measure only not set. Drawing." -Append -Component "Draw-Information"
    }
    #Loop through all the object we need to draw on the desktop
    foreach($Item in $ItemsXMLNode.ChildNodes)
    {
        if ($Item.Name -eq "Label")
        {
            #Cleanup the received parameters from the XML file
            $Value = Invoke-Expression $Item.Value -ErrorAction SilentlyContinue
            Write-Log -Message ("Value is "+$Value) -Component "Draw-Information" -Append
            $Brush = Get-GraphicsTool -RefName $Item.BrushRefName -DrawingTools $DrawingTools -Default "DefaultBrush"
            $Font = Get-GraphicsTool -RefName $Item.FontRefName -DrawingTools $DrawingTools -Default "DefaultHeaderFont"
 
            $Size = $Graphics.MeasureString($Value, $Font)
            if (-not $MeasureOnly)
            {
                #Draw the string
                $Graphics.DrawString($Value, $Font, $Brush, $XOffset+($Width/2)-($Size.Width/2),$YOffset);
            }
            #Adjust the Y offset to shift the next item down (Prevents rendering ontop of other items)
            $YOffset += $Size.Height
        }
        elseif ($Item.Name -eq "List")
        {
            #Grab brushes, and double check parameters
            $NameBrush = Get-GraphicsTool -RefName $Item.NameBrushRefName -DrawingTools $DrawingTools -Default "DefaultBrush"
            $NameFont = Get-GraphicsTool -RefName $Item.NameFontRefName -DrawingTools $DrawingTools -Default "DefaultNameFont"
            $ValueBrush = Get-GraphicsTool -RefName $Item.ValueBrushRefName -DrawingTools $DrawingTools -Default "DefaultBrush"
            $ValueFont = Get-GraphicsTool -RefName $Item.ValueFontRefName -DrawingTools $DrawingTools -Default "DefaultValueFont"
            $ValueJustification = $Item.ValueJustification
            $ValueOffset = $Item.ValueOffset
            #Generate a list based on the XML file. List will be used with DrawList
            $List = @() # @(@{Name="IP";Value="127.0.0.1"},@{Name="User";Value=($env:USERDOMAIN+"\"+$env:USERNAME)})
            foreach($ListItem in $Item.GetElementsByTagName("ListItem"))
            {
                #Evaluate the name and value, then add it to the list to be rendered.
                $Name = $ListItem.ItemName.Trim()
                $Value = (Invoke-Expression $ListItem.Value -ErrorAction SilentlyContinue)
                $List += @{Name=$Name;Value=$Value}
                Write-Log -Message ("Line added to list. '"+$Name+": '"+$Value+"'") -Component "Draw-Information" -Append
            }
            #Render or measure the list. If $MeasureOnly is set, DrawList only returns the height of what it would have drawn
            $ListHeight= DrawList -List $List -NameBrush $NameBrush -NameFont $NameFont -ValueJustification $ValueJustification -ValueOffset $ValueOffset `
             -ValueBrush $ValueBrush -ValueFont $ValueFont `
             -Width $Width -X ($XOffset) -Y ($YOffset) -Graphics $Graphics -EstimateOnly:$MeasureOnly
             #Adjust the Y offset to shift the next item down (Prevents rendering ontop of other items)
            $YOffset += $ListHeight
        }
        elseif ($Item.Name -eq "Divider")
        {
            #Grab brush and ensure Height is not ridiculous. (Ok [int]::MaxValue is ridiculous, but it won't throw a math error like -1 would)
            $DividerHeight = Restrain-Int -Value $Item.Height -Min 1 -Max ([int]::MaxValue) -Default 5 -Name "DividerHeight"
 
            $Brush = Get-GraphicsTool -RefName $Item.BrushRefName -DrawingTools $DrawingTools -Default "DefaultBrush"
            if (-not $MeasureOnly)
            {
                #Draw the divider
                $Graphics.FillRectangle($Brush, $XOffset, $YOffset, $Width, $DividerHeight);
            }
            #Adjust the Y offset to shift the next item down (Prevents rendering ontop of other items)
            $YOffset += $DividerHeight
        }
        elseif ($Item.Name -eq "Image")
        {
            #Attempt to resolve image path and size
            $Path = Resolve-Path $Item.Path.Trim() -ErrorAction SilentlyContinue
            $ImageHeight = $null
            $ImageWidth = $null
            if ($Item.Height -ne $null -and $Item.Height.Trim() -ne "Auto")
            {
                $ImageHeight = Restrain-Int -Value $Item.Height -Min 1 -Max ([int]::MaxValue) -Default 100 -Name "ImageHeight"
            }
            if ($Item.Width.Trim() -eq "Auto")
            {
                if ($ImageHeight -eq $null)
                {
                    $ImageWidth = $Width
                    Write-Log -Message "Image width autosized." -Component "Draw-Information" -Append
                }
            }
            else
            {
                $ImageWidth = Restrain-Int -Value $Item.Width -Min 1 -Max $Width -Default $Width -Name "ImageWidth"
            }
            if ($Path -ne $null -and (Test-Path $Path))
            {
                #We can skip this chunk of time consuming code if we have statically set height, width and are only doing a measure. If not, we need to get the image size info.
                if (-not $MeasureOnly -or $ImageHeight -eq $null -or $ImageWidth -eq $null)
                {
                    #load the image
                    $Image = [System.Drawing.Image]::FromFile($Path)
                    #Adjust the size variables now that we have the image loaded
                    if ($ImageHeight -eq $null)
                    {
                        $ImageHeight=Restrain-Int -Value ($Image.Height/($Image.Width/$ImageWidth)) -Min 1 -Max ([int]::MaxValue) -Default 100 -Name "ImageHeight"
                        Write-Log -Message "Image height autosized." -Component "Draw-Information" -Append
                    }
                    if ($ImageWidth -eq $null)
                    {
                        $ImageWidth=Restrain-Int -Value ($Image.Width/($Image.Height/$ImageHeight)) -Min 1 -Max $Width -Default $Width -Name "ImageWidth"
                        Write-Log -Message "Image width autosized based on height." -Component "Draw-Information" -Append
                    }
                    if (-not $MeasureOnly)
                    {
                        #Draw the image if we are not measuring only
                        $Graphics.DrawImage($Image, $XOffset+($Width/2-$ImageWidth/2), $YOffset, $ImageWidth,$ImageHeight);
                    }
                    #Cleanup memory
                    $Image.Dispose();
                }
                #Adjust the Y offset to shift the next item down (Prevents rendering ontop of other items)
                $YOffset += $ImageHeight
            }
            else
            {
                Write-Log -Error -Message ("Image does not exist "+$Path) -Component "Draw-Image" -Append
            }
        }
        #TODO: Add More XML Elements here.
    }
    return $YOffset - $OrigYOffset
}
#endregion
 
#endregion
 
#Entry point
Write-Log -Component "SCRIPT" -Message ($ScriptName+", version "+$Version+", started.") -Append:$false
$PSBoundParameters.Keys | ForEach-Object -Process {Write-Log -Component "PARAM" -Message ("`""+$_+"`" = `""+$PSBoundParameters[$_]+"`"") -Append}
 
if (-not ($InformationPath -and (Test-Path $InformationPath)))
{
    $InformationPath = $null
    Write-Log -Append -Message ("Could not load: "+$InformationPath) -Component "SCRIPT"
}
 
#region Calculate total image size and offset
$ScreenBounds=@{Left=0;Top=0;Right=0;Bottom=0;}
$Screens = [System.Windows.Forms.Screen]::AllScreens
 
foreach($Screen in $Screens)
{
    if ($Screen.Bounds.Left -lt $ScreenBounds.Left)
    {
        $ScreenBounds.Left=$Screen.Bounds.Left
    }
    if ($Screen.Bounds.Right -gt $ScreenBounds.Right)
    {
        $ScreenBounds.Right=$Screen.Bounds.Right
    }
    if ($Screen.Bounds.Top -lt $ScreenBounds.Top)
    {
        $ScreenBounds.Top = $Screen.Bounds.Top
    }
    if ($Screen.Bounds.Bottom -gt $ScreenBounds.Bottom)
    {
        $ScreenBounds.Bottom = $Screen.Bounds.Bottom
    }
}
 
$ImageSize = @{ Width=[Math]::Abs($ScreenBounds.Left)+$ScreenBounds.Right;
                    Height=[Math]::Abs($ScreenBounds.Top)+$ScreenBounds.Bottom;
                    HOffset=[Math]::Abs($ScreenBounds.Left);
                    VOffset=[Math]::Abs($ScreenBounds.Top);}
#endregion
 
#Create new image
$Image = new-object -TypeName "System.Drawing.Bitmap" -ArgumentList @($ImageSize.Width,$ImageSize.Height)
#Create a graphics object to manipulate the image
$Graphics = [System.Drawing.Graphics]::FromImage($Image)
 
#To prevent recreating of common drawing variables, storing them in a hashtable. This also allows us to dynamically call upon different brushes and fonts.
$DrawingTools=@{DefaultHeaderFont=New-Object System.Drawing.Font("Ariel", 24, [System.Drawing.FontStyle]::Underline);
                DefaultBrush=new-object System.Drawing.SolidBrush([System.Drawing.Color]::White);
                DefaultNameFont=New-Object System.Drawing.Font("Ariel", 12, [System.Drawing.FontStyle]::Bold);
                DefaultValueFont=New-Object System.Drawing.Font("Ariel", 12);}
 
#Load the list information
$OptionsFile = $null
if ($InformationPath)
{
    try
    {
        $OptionsFile = [xml] (Get-Content $InformationPath)
    }
    catch
    {
        Write-Log -Error -Message ("Failed to load XML information, will continue with defaults. "+$_.ToString()) -Component "SCRIPT" -Append
        $InformationPath = $null
    }
 
    #region Load DrawingTools
    $ToolsNode = @()
    $ToolsNode += $OptionsFile.Information.GetElementsByTagName("GraphicsTools");
    if ($ToolsNode.Count -eq 1)
    {
        #Ensure ToolsNode is not an array
        $ToolsNode = $ToolsNode[0]
        #Foreach GraphicsTool, load it and add it to the tool array
        foreach($GraphicsObject in $ToolsNode.ChildNodes)
        {
            if ($GraphicsObject.Name -eq "Font")
            {
                $NewFont = New-Object System.Drawing.Font($GraphicsObject.FontName, $GraphicsObject.FontSize, [System.Drawing.FontStyle]($GraphicsObject.FontStyle));
                if ($DrawingTools.ContainsKey($GraphicsObject.ReferenceName))
                {
                    $DrawingTools[$GraphicsObject.ReferenceName]=$NewFont
                    Write-Log -Message ("Overwrote tool: "+$GraphicsObject.ReferenceName) -Component "LoadTools" -Append
                }
                else
                {
                    $DrawingTools.Add($GraphicsObject.ReferenceName,$NewFont)
                    Write-Log -Message ("Added tool: "+$GraphicsObject.ReferenceName) -Component "LoadTools" -Append
                }
            }
            elseif ($GraphicsObject.Name -eq "Brush")
            {
                #Convert string to color
                $Values = $GraphicsObject.Color.Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
                $Color = @{A=[int]255; R=[int]255; G=[int]255; B=[int]255}
                try
                {
                    if ($Values.Length -eq 3 -or $Values.Length -eq 4)
                    {
                        $Offset = $Values.Length-3
                        if ($Values.Length -eq 4)
                        {
                            $Color.A = Restrain-Int -Value ([int]$Values[0]) -Min 0 -Max 255
                        }
                        $Color.R = Restrain-Int -Value ([int]$Values[$Offset]) -Min 0 -Max 255
                        $Color.G = Restrain-Int -Value ([int]$Values[$Offset+1]) -Min 0 -Max 255
                        $Color.B = Restrain-Int -Value ([int]$Values[$Offset+2]) -Min 0 -Max 255
                    }
                    else
                    {
                        Write-Log -Message ("Color not properly formatted: "+$GraphicsObject.ReferenceName+". ") -Component "LoadTools" -Warning -Append
                    }
                }
                catch
                {
                    Write-Log -Message ("Color not properly formatted: "+$GraphicsObject.ReferenceName+". "+$_.ToString()) -Component "LoadTools" -Warning -Append
                }
                #Create the brush
                $NewBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($Color.A, $Color.R, $Color.G, $Color.B));
                if ($DrawingTools.ContainsKey($GraphicsObject.ReferenceName))
                {
                    $DrawingTools[$GraphicsObject.ReferenceName]=$NewBrush
                    Write-Log -Message ("Overwrote tool: "+$GraphicsObject.ReferenceName) -Component "LoadTools" -Append
                }
                else
                {
                    $DrawingTools.Add($GraphicsObject.ReferenceName,$NewBrush)
                    Write-Log -Message ("Added tool: "+$GraphicsObject.ReferenceName) -Component "LoadTools" -Append
                }
            }
            else
            {
                Write-Log -Message -Warning ("Unknown graphics tool. ("+$GraphicsNode.Name+")") -Component "LoadTools" -Append
            }
        }
    }
    #endregion
}
 
#region Resolve Background
$BaseImage = $null
$BaseImagePosition="Fill"
#Resolve base image for background
if (-not $NoBaseBG)
{
    if ($BaseImageLocation -and (Test-Path $BaseImageLocation))
    {
        #Load the base image
        $BaseImage = [System.Drawing.Image]::FromFile($BaseImageLocation)
    }
    elseif ($InformationPath)
    {
        #Grab from OptionsFile
        $BaseImageLocation = Resolve-Path $OptionsFile.Information.Background.BaseImageLocation.Trim()
        $BaseImagePosition = $OptionsFile.Information.Background.Positioning.Trim()
        if ($BaseImagePosition -ne "Center" -and $BaseImagePosition -ne "Fill" -and $BaseImagePosition -ne "Tile")
        {
            $BaseImagePosition = "Fill"
            Write-Log -Message ("Base image position not correct in XML file. Defaulting to 'Fill'") -Warning -Component "ResolveBaseImage" -Append
        }
        else
        {
            Write-Log -Message ("Base image position set to '$BaseImagePosition'.") -Component "ResolveBaseImage" -Append
        }
        if (Test-Path $BaseImageLocation)
        {
            try
            {
                $BaseImage = [System.Drawing.Image]::FromFile($BaseImageLocation)
                Write-Log -Message ("Base image set. ($BaseImageLocation)") -Component "ResolveBaseImage" -Append
            }
            catch
            {
                $BaseImageLocation = $null
                Write-Log -Message ("Base image could not be found or resolved from XML file. "+$_.ToString()) -Error -Component "ResolveBaseImage" -Append
            }
        }
        else
        {
            $BaseImageLocation = $null
            Write-Log -Message "Base image could not be found or resolved from XML file." -Component "ResolveBaseImage" -Append
        }
    }
    if ($BaseImage -eq $null)
    {
        #If the base image does not exist. Use one of the default windows backgrounds. Suppressed with -NoBaseBG
        $DefaultBGs=Get-ChildItem -Path "C:\Windows\Web\Wallpaper" -include @("*.jpg","*.bmp") -Recurse
        $Randomer = New-Object Random
        $BaseImageLocation = $DefaultBGs[$Randomer.Next(0,$DefaultBGs.Length)].FullName
        $BaseImage = [System.Drawing.Image]::FromFile($BaseImageLocation)
        Write-Log -Message "Base image not set. Using a random default. ($BaseImageLocation)" -Component "ResolveBaseImage" -Append
    }
    else
    {
        Write-Log -Message "Base image not set. Default suppressed." -Component "ResolveBaseImage" -Append
    }
}
#endregion
 
#region Get MarginOffset
#The margin offset allows the user to offset the information from the xml file.
$MarginXOffset =0
$MarginYOffset =0
if ($InformationPath -and $OptionsFile.Information.Offset)
{
    $Values = $OptionsFile.Information.Offset.Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($Values.Length -eq 2)
    {
        $MarginXOffset = Restrain-Int -Value ([int]$Values[0]) -Min ([int]::MinValue) -Max ([int]::MaxValue) -Default 0
        $MarginYOffset = Restrain-Int -Value ([int]$Values[1]) -Min ([int]::MinValue) -Max ([int]::MaxValue) -Default 0
    }
    else
    {
        Write-Log -Message "Could not add offset as offset was not set correctly." -Warning -Append -Component "MarginOffsets"
    }
}
#endregion
 
#region Draw Image
foreach($Screen in $Screens)
{
    $ScreenOffset=@{X=$ImageSize.HOffset+$Screen.Bounds.X;Y=$ImageSize.VOffset+$Screen.Bounds.Y}
    #Draw bottom up. (Background first, foreground last)
    #Remember to add the Hoffset and VOffset along with the screen's boundaries, or your things may not end up where you expect in relation to the screen.
    #TODO: Add custom drawing logic here
    if ($BaseImage)
    {
        #Draw the base image.
        if ($BaseImagePosition -eq "Center")
        {
            $Graphics.DrawImage($BaseImage, $ScreenOffset.X+($Screen.Bounds.Width/2-$BaseImage.Width/2), $ScreenOffset.Y+($Screen.Bounds.Height/2-$BaseImage.Height/2), $BaseImage.Width, $BaseImage.Height)
        }
        elseif ($BaseImagePosition -eq "Tile")
        {
            if (-not $DrawingTools.ContainsKey("TileBrush"))
            {
                $TileBrush = New-Object System.Drawing.TextureBrush($BaseImage, [System.Drawing.Drawing2D.WrapMode]::Tile)
                $DrawingTools.Add("TileBrush", $TileBrush);
            }
            $Graphics.FillRectangle($DrawingTools["TileBrush"], $ScreenOffset.X, $ScreenOffset.Y, $Screen.Bounds.Width, $Screen.Bounds.Height);
        }
        else
        {
            #Fill or null
            $Graphics.DrawImage($BaseImage, $ScreenOffset.X, $ScreenOffset.Y, $Screen.Bounds.Width, $Screen.Bounds.Height)
        }
 
    }
    if ($Screen.Bounds.X -eq 0 -and $Screen.Bounds.Y -eq 0)
    {
        #Primary Screen
        if (-not $InformationPath)
        {
            #Draw the computer name in the upper right corner of the primary monitor
            $Size = $Graphics.MeasureString($env:COMPUTERNAME, $DrawingTools.DefaultHeaderFont)
            $Graphics.DrawString($env:COMPUTERNAME, $DrawingTools.DefaultHeaderFont, $DrawingTools.DefaultBrush, $ScreenOffset.X+$Screen.Bounds.Width-$Size.Width,$ScreenOffset.Y+0);
            $List = @(@{Name="IP";Value="127.0.0.1"},@{Name="User";Value=($env:USERDOMAIN+"\"+$env:USERNAME)})
            $ListHeight= DrawList -List $List -NameBrush $DrawingTools.DefaultBrush -NameFont $DrawingTools.DefaultNameFont `
             -ValueBrush $DrawingTools.DefaultBrush -ValueFont $DrawingTools.DefaultValueFont `
             -Width $Size.Width -X ($ScreenOffset.X+$Screen.Bounds.Width-$Size.Width) -Y ($Size.Height+$ScreenOffset.Y) -Graphics $Graphics
        }
    }
    else
    {
        #All non-primary screens
 
    }
 
    if ($OptionsFile.Information.Screen.Trim() -eq "All" -or 
        (($Screen.Bounds.X -eq 0 -and $Screen.Bounds.Y -eq 0) -and ($OptionsFile.Information.Screen.Trim() -eq "Primary" -or  $OptionsFile.Information.Screen -eq $null)))
    {
        $XOffset = 0;
        $YOffset = 0;
        $XAnchor = "Right"
        $YAnchor = "Upper"
        $ListWidth = $OptionsFile.Information.Width.Trim()
        try
        {
            $XAnchor = $OptionsFile.Information.Anchor.Trim().Split("-")[1];
            $YAnchor = $OptionsFile.Information.Anchor.Trim().Split("-")[0];
        }
        catch
        {
            $XAnchor = "Right"
            $YAnchor = "Upper"
        }
        if ($XAnchor -eq "Right")
        {
            $XOffset = $Screen.Bounds.Width + $ScreenOffset.X - $ListWidth + $MarginXOffset
        }
        elseif ($XAnchor -eq "Left")
        {
            $XOffset = $ScreenOffset.X + $MarginXOffset
        }
        elseif ($XAnchor -eq "Center" -or $XAnchor -eq "Middle" -or $XAnchor -eq "Mid")
        {
            $XOffset = ($Screen.Bounds.Width/2) + $ScreenOffset.X - ($ListWidth/2) + $MarginXOffset
        }
        else
        {
            $XOffset = $Screen.Bounds.Width + $ScreenOffset.X - $ListWidth + $MarginXOffset
            Write-Log -Message "Defaulted anchor to 'Right'." -Component "ScreenDrawLoop" -Append -Warning
        }
        if ($YAnchor -eq "Upper" -or $YAnchor -eq "Top")
        {
            $YOffset = $ScreenOffset.Y+ $MarginYOffset
        }
        elseif ($YAnchor -eq "Bottom" -or $YAnchor -eq "Lower")
        {
            $EstimatedHeight = Draw-Information -ItemsXMLNode $OptionsFile.Information.Items -DrawingTools $DrawingTools -Graphics $Graphics -XOffset 0 -YOffset 0 -Width $ListWidth -MeasureOnly
            $YOffset = $ScreenOffset.Y+($Screen.WorkingArea.Height-$EstimatedHeight)+ $MarginYOffset
        }
        elseif ($YAnchor -eq "Center" -or $YAnchor -eq "Middle" -or $YAnchor -eq "Mid")
        {
            $EstimatedHeight = Draw-Information -ItemsXMLNode $OptionsFile.Information.Items -DrawingTools $DrawingTools -Graphics $Graphics -XOffset 0 -YOffset 0 -Width $ListWidth -MeasureOnly
            $YOffset = $ScreenOffset.Y+($Screen.WorkingArea.Height/2-$EstimatedHeight/2)+ $MarginYOffset
        }
        else
        {
            $YOffset = $ScreenOffset.Y+ $MarginYOffset
            Write-Log -Message "Defaulted anchor to 'Upper'." -Component "ScreenDrawLoop" -Append -Warning
        }
        $ListHeight = Draw-Information -ItemsXMLNode $OptionsFile.Information.Items -DrawingTools $DrawingTools -Graphics $Graphics -XOffset $XOffset -YOffset $YOffset -Width $ListWidth
    }
}
#endregion
 
#region Save image and cleanup memory
$Graphics.Flush();
$Graphics.Dispose();
 
#Create image encorder to manually specify the quality of the saved image
#TODO: To customize quality change the Mimetype and the quality parameter
$ImgEncoder = Get-Encoder -MimeType "image/jpeg" # "/png", "/bmp", "/gif"
$EncoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$EncoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 100) # Quality, think percentage. 100 quality is best.
 
#Save the image
$Image.Save($SavePath, $ImgEncoder, $EncoderParams);
 
#More memory cleaning
if ($BaseImage)
{
    $BaseImage.Dispose()
}
$Image.Dispose()
#endregion
 
#Set the wallpaper to the newly created image
Set-WallPaper -Path $SavePath
