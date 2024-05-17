## This is madness
$scriptDir = $PWD
$iniFilePath = "$scriptDir\config.ini"
$runAsToolPath = Join-Path -Path $scriptDir -ChildPath "bin\RunAsTool.exe"
$arguments = "/R /U=Administrator /P=1 /I=config.rnt"


function Countdown {
    param (
        [int]$seconds
    )
	
	Write-Host "Menu will launch in 3 seconds. Press any key to enter configuration"
    $startTime = Get-Date

    while ((Get-Date) -lt $startTime.AddSeconds($seconds)) {
        #Write-Host ($startTime.AddSeconds($seconds) - (Get-Date)).Seconds
		Write-Host "." -NoNewLine
        Start-Sleep -Milliseconds 100

        # Check if a key was pressed
        if ([System.Console]::KeyAvailable) {
            # Clear the buffer
            [System.Console]::ReadKey() | Out-Null
            return $true
        }
    }

    return $false
}

function Replace-StringInFile {
    param (
        [string]$filePath,
        [string]$oldString,
        [string]$newString
    )

    # Read the file content
    $fileContent = Get-Content -Path $filePath

    # Perform the replacement
    $updatedContent = $fileContent -replace [regex]::Escape($oldString), [regex]::Escape($newString)

    # Write the updated content back to the file
    Set-Content -Path $filePath -Value $updatedContent
}

function Get-IniValue {
    param (
        [string]$filePath,
        [string]$section,
        [string]$key
    )

    # Read the content of the INI file
    $iniContent = Get-Content -Path $filePath

    # Initialize variables
    $inSection = $false
    $value = $null

    # Loop through each line in the INI file
    foreach ($line in $iniContent) {
        # Check if the line is a section header
        if ($line -match '^\[(.+)\]$') {
            # Check if the section is the one we are looking for
            if ($matches[1] -eq $section) {
                $inSection = $true
            } else {
                $inSection = $false
            }
        }
        # Check if we are in the correct section and the line contains the key
        elseif ($inSection -and $line -match '^\s*([^=]+)\s*=\s*(.+)\s*$') {
            if ($matches[1].Trim() -eq $key) {
                $value = $matches[2].Trim()
                break
            }
        }
    }

    # Return the value
    return $value
}

function Set-IniValue {
    param (
        [string]$filePath,
        [string]$section,
        [string]$key,
        [string]$value
    )

    # Read the content of the INI file
    $iniContent = Get-Content -Path $filePath

    # Initialize variables
    $inSection = $false
    $keyUpdated = $false

    # Create a new array to store updated content
    $updatedContent = @()

    # Loop through each line in the INI file
    foreach ($line in $iniContent) {
        # Check if the line is a section header
        if ($line -match '^\[(.+)\]$') {
            # Check if the section is the one we are looking for
            if ($matches[1] -eq $section) {
                $inSection = $true
            } else {
                $inSection = $false
            }
        }

        # Check if we are in the correct section and the line contains the key
        if ($inSection -and $line -match '^\s*([^=]+)\s*=\s*(.+)\s*$') {
            if ($matches[1].Trim() -eq $key) {
                # Update the key with the new value
                $updatedContent += "$key=$value"
                $keyUpdated = $true
            } else {
                $updatedContent += $line
            }
        } else {
            $updatedContent += $line
        }
    }

    # If the key was not found in the section, add it
    if (-not $keyUpdated -and $inSection) {
        $updatedContent += "$key=$value"
    }

    # Write the updated content back to the INI file
    $updatedContent | Set-Content -Path $filePath
}

function RunAsTool {
	Write-Host " "
	# Read the 'path' key from the 'main' section
	$section = "main"
	$key = "path"

	# Get the current value of the 'path' key
	$currentValue = Get-IniValue -filePath $iniFilePath -section $section -key $key
	Write-Host "[DEBUG] Current value of [$section] $key is: $currentValue"

	# Update the 'path' key with the value of $scriptDir
	Set-IniValue -filePath $iniFilePath -section $section -key $key -value $scriptDir

	# Output the updated value
	$updatedValue = Get-IniValue -filePath $iniFilePath -section $section -key $key
	Write-Host "[DEBUG] The updated value of [$section] $key is: $updatedValue"

	# Run the RunAsTool.exe with the specified arguments
	$runAsToolPath = Join-Path -Path $scriptDir -ChildPath "bin\RunAsTool.exe"
	$arguments = "/R /U=Administrator /P=Password /I=config.rnt"

	Write-Host "Running RunAsTool.exe with the specified arguments"
	& $runAsToolPath $arguments
}

function Write-Message {
    param(
        [string]$Symbol,
        [string]$Message
    )

    switch ($Symbol) {
        "+" {
            Write-Host -ForegroundColor Black -BackgroundColor Green -NoNewline "[+]"
        }
        "-" {
            Write-Host -ForegroundColor Black -BackgroundColor Yellow -NoNewline "[-]"
        }
        "E" {
            Write-Host -ForegroundColor Black -BackgroundColor Red -NoNewline "[E]"
        }
        "#" {
            Write-Host -ForegroundColor Black -BackgroundColor Cyan -NoNewline "[#]"
        }
        default {
            Write-Host -ForegroundColor Black -NoNewline "[ $Symbol ]"
        }
		
		"[DEBUG]" {
				   If ($DEBUG -gt 0) {
					   Write-Host -ForegroundColor Black -BackgroundColor Magenta "[DEBUG]"
					}
		}
    }			
	
    $Delay = 350
    Write-Host -ForegroundColor White " $Message"
    Start-Sleep -Milliseconds $Delay
}

function Ensure-ModulesInstalled {
    [CmdletBinding()]
    param (
        [string[]]$ModuleNames
    )

    # Check if each module is installed, and if not, install it
    foreach ($moduleName in $ModuleNames) {
        if (-not (Get-Module -Name $moduleName -ListAvailable)) {
            Write-Message "E" "Module '$moduleName' is not installed."
			Write-Message "-" "Installing $moduleName"
            Install-Module -Name $moduleName -Force
            Write-Message "+" "Module '$moduleName' installed successfully."
        } else {
            Write-Message "#" "Module '$moduleName' is already installed."
        }
    }
}

function Test-PathEx {
    param (
        [string]$Path
    )

    $pathValid = Test-Path $Path
    if ($pathValid -eq 'True') {
        Write-Message "+" "Path Valid: $path"
    } else {
        Write-Message "E" "Error. Path '$Path' does not exist."
		Write-Message "Abortion. Exiting."
		pause
		exit
    }
}

function Show-BorderedMenuFixed {
    param (
        [string]$Title,
        [array]$MenuOptions,
        [int]$Width = 40,  # Default width
        [int]$Height = 10,  # Default height
        [bool]$StaticSize = $true  # Default to static size
    )

    $borderTop = $conersChar + $lineChar * ($Width - 2) + $conersChar
    $borderBottom = $conersChar + $lineChar * ($Width - 2) + $conersChar
    $borderSide = $sideChar

    $titlePadded = $Title.PadRight($Width - 4, ' ')  # Adjust for border characters

    Write-Host $borderTop
    Write-Host "$borderSide $titlePadded $borderSide"
    Write-Host $borderTop

    if ($StaticSize) {
        $availableLines = $Height - 4  # Deduct space for top border, title, and bottom border
    } else {
        $availableLines = $MenuOptions.Count
    }

    for ($i = 0; $i -lt $availableLines -and $i -lt $MenuOptions.Count; $i++) {
        $optionPadded = $MenuOptions[$i].PadRight($Width - 4, ' ')  # Adjust for border characters
        Write-Host "$borderSide $optionPadded $borderSide"
    }

    # Fill remaining lines with side walls if using dynamic size
    if (!$StaticSize) {
        for ($i = $MenuOptions.Count; $i -lt $Height - 4; $i++) {
            $sideWall = "$borderSide" + " " * ($Width - 2) + "$borderSide"
            Write-Host "$sideWall"
        }
    }

    Write-Host $borderBottom
}

function SplashMe {
    param([string]$Text)

    $Text.ToCharArray() | ForEach-Object {
        switch -Regex ($_){
            "`r" {
                break
            }
            "`n" {
                Write-Host " "; break
            }
            "[^ ]" {
                $writeHostOptions = @{
                    NoNewLine = $true
                }
                Write-Host $_ @writeHostOptions
                break
            }
            " " {
                Write-Host " " -NoNewline
            }
        } 
    }
}

function Write-HyphenToEnd {
    $consoleWidth = [Console]::WindowWidth
    Write-Host ("-" * $consoleWidth)
}

function Write-CatHeader {
    $width = $Host.UI.RawUI.BufferSize.Width
    
    $asciiArt1 = "    |\__/,|   (`\"
    $asciiArt2 = "  _.|o o  |_   ) )"
    $asciiArt3 = "-(((---(((--------"

    # Calculate the number of dashes needed to pad the ASCII art to match the width
    $padding = ($width - $asciiArt3.Length)
	$dashLine = '-' * ($width - 19)
	
    # Output ASCII art 1 and 2 with appropriate padding
	#Write-Host ""
	Write-Host (" " * ($padding - 70))""
    Write-Host (" " * ($padding - 1))$asciiArt1
    Write-Host (" " * ($padding - 1))$asciiArt2
	Write-Host $dashLine $asciiArt3
    #Write-Host (" " * ($padding - 2))$asciiArt3 -NoNewLine

    
}

function TypeWrite {
	param(
	[string]$text, 
	[int]$speed = 200
)

	try {
		$Random = New-Object System.Random
		$text -split '' | ForEach-Object {
			Write-Host -noNewline $_
			Start-Sleep -milliseconds $(1 + $Random.Next($speed))
		}
		Write-Host ""
	} catch {
		"Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
		exit 1
	}
}

$splashMenu = @"

  __  __                               __    ____ _           _          
 |  \/  | ___ _ __ ___  _   _    ___  / _|  / ___| |__   ___ (_)___  ___ 
 | |\/| |/ _ \ '_ ` _  \| | | |  / _ \| |_  | |   | '_ \ / _ \| / __|/ _ \
 | |  | |  __/ | | | | | |_| | | (_) |  _| | |___| | | | (_) | \__ \  __/
 |_|  |_|\___|_| |_| |_|\__,_|  \___/|_|    \____|_| |_|\___/|_|___/\___|
                                                                         
"@

$splashTitle = @"

                                                                                   
 _____             _                    _    _____ _____ _____                     
|     |___ _ _ ___| |_ ___    ___ ___ _| |  |_   _|     | __  |                    
|   --|  _| | | . |  _| . |  | .'|   | . |    | | |  |  |    -|                    
|_____|_| |_  |  _|_| |___|  |__,|_|_|___|    |_| |_____|__|__|                    
          |___|_|                                                                  
                                                                                   
 ____                _           _            _____       _     _                  
|    \ ___ _ _ _ ___| |___ ___ _| |___ ___   |  |  |___ _| |___| |_ ___ ___        
|  |  | . | | | |   | | . | .'| . | -_|  _|  |  |  | . | . | .'|  _| -_|  _|       
|____/|___|_____|_|_|_|___|__,|___|___|_|    |_____|  _|___|__,|_| |___|_|         
                                                   |_|                             
                                                                                   
 _____         _    _____         _     _      _____     ___ _                     
|_   _|___ ___| |  |   __|___ ___|_|___| |_   |   __|___|  _| |_ _ _ _ ___ ___ ___ 
  | | | . | . | |  |__   |  _|  _| | . |  _|  |__   | . |  _|  _| | | | .'|  _| -_|
  |_| |___|___|_|  |_____|___|_| |_|  _|_|    |_____|___|_| |_| |_____|__,|_| |___|
                                   |_|                                             									  
"@

function launchWhales {
	param(
	[int]$mOption
	)
	
		If ($mOption -eq 1) {
			downloadElectrum
		}
		
		If ($mOption -eq 2) {
			downloadMonero
		}
		
		If ($mOption -eq 3) {
			downloadTor
		}
	
}

function downloadElectrum {
	Write-Host "####---  Electrum Portable  ---####"
	Start-Sleep -Milliseconds 450

	Write-Message "-" "Parsing Download URL from electrum.org"
	Start-Sleep -Seconds 1
	# Define the URL to parse
	$url = "https://electrum.org/#download"

	# Use Invoke-WebRequest to get the HTML content of the page
	$response = Invoke-WebRequest -Uri $url

	# Parse the HTML content to find Download URLs
	$downloadLinks = $response.Links | Where-Object { $_.href -match "download.electrum.org" }

	# Find the link ending with 'portable.exe'
	$portableLink = $downloadLinks | Where-Object { $_.href -like "*portable.exe" }
	Write-Message "+" "Download URL found"

	# If the portable link is found, download the file
	if ($portableLink) {
		$portableUrl = $portableLink.href
		Write-Message "-" "Starting Download: $portableLink"
		$fileName = [System.IO.Path]::GetFileName($portableUrl)
		$outputPath = Join-Path -Path $scriptDir -ChildPath "\$fileName"
		
		Invoke-WebRequest -Uri $portableUrl -OutFile $outputPath
		Write-Message "+" "Downloaded: $portableUrl to $outputPath"
		Write-Message "#" "File name: $fileName"
	} else {
		Write-Message "E" "Error. Portable version not found."
		Write-Message "Abortion. Exiting..."
		Pause
		exit
	}
}

function downloadMonero {
	Write-Message "####---  Monero Portable  ---####"
	Start-Sleep -Milliseconds 450
	# URL of the webpage
	$url = "https://www.getmonero.org/downloads/"

	Write-Message "-" "Parsing Download URL from getmonero.org"
	Start-Sleep -Seconds 1
	# Make the web request
	$response = Invoke-WebRequest -Uri $url

	# Check if the request was successful
	if ($response.StatusCode -eq 200) {
		# Parse the HTML content
		$html = $response.Content

		# Search for the version number using a regular expression
		$pattern = '(?<=Current Version:</i> )[\d.]+'
		$currentVersion = [regex]::Match($html, $pattern).Value

		# Check if the version is not empty
		if (![string]::IsNullOrEmpty($currentVersion)) {
			# Print the current version
			Write-Message "#" "Current version: $currentVersion"

			# Detect the host architecture (32-bit or 64-bit)
			$hostArchitecture = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

			# Construct Download URL based on host architecture
			$portableLink = "https://downloads.getmonero.org/gui/monero-gui-win-$hostArchitecture-v$currentVersion.zip"
			Write-Message "+" "Download URL found"
			
			# Check if the Download URL exists
			if ($portableLink) {
				$fileName = "monero-gui-win-$hostArchitecture-v$currentVersion.zip"
				Write-Message "-" "Starting Download: $portableLink"
				Write-Message "#" "File Name: $fileName"
				$outputPath = Join-Path -Path $scriptDir -ChildPath $fileName
				Write-Message "#" "Output Path: $outputPath"
				Invoke-WebRequest -Uri $portableLink -OutFile $outputPath
				Write-Message "+" "Downloaded: $portableLink to $outputPath"
			} else {
				Write-Message "E" "Error. Portable version not found."
				Write-Message "Abortion. Exiting."
				Pause
				exit
			}
		} else {
			Write-Message "E" "Error. Current version not found."
			Write-Message "Abortion. Exiting."
			Pause
			exit
		}
	} else {
		Write-Message "E" "Error. Failed to retrieve the webpage. Status code: $($response.StatusCode)"
		Write-Message "Abortion. Exiting."
		Pause
		exit
	}
}

function downloadTor {
	Write-Message "####---  Tor Browser  ---####"
	Start-Sleep -Milliseconds 450
	# HTML snippet containing the Download URL
	Write-Message "-" "Parsing Download URL from torproject.org"
	Start-Sleep -Seconds 1
	$htmlSnippet = '<a class="btn btn-primary mt-4 downloadLink" href="/dist/torbrowser/13.0.15/tor-browser-windows-x86_64-portable-13.0.15.exe">Download for Windows</a>'

	# Extract the relative URL of the Download URL using a regular expression
	$pattern = 'href="([^"]+/tor-browser-windows-x86_64-portable[^"]+)">'
	$match = [regex]::Match($htmlSnippet, $pattern)

	# Check if a match was found
	if ($match.Success) {
		# Extract the relative URL
		$relativeURL = $match.Groups[1].Value

		# Construct the complete Windows Download URL
		$baseURL = "https://www.torproject.org"
		$torLatestLink = "$baseURL$relativeURL"
		Write-Message "+" "Lastest URL Found"
		Write-Message "#" $torLatestLink
		
		Write-Message "-" "Downloading latest tor browser"
		$outputPath = Join-Path -Path $scriptDir -ChildPath "\tor-browser-windows-x86_64-portable.exe"
		Write-Message "#" "Output Path: $outputPath"
		Invoke-WebRequest -Uri $torLatestLink -OutFile $outputPath
		Write-Message "+" "Downloaded: $torLatestLink to $outputPath"
	   
	} else {
		Write-Message "E" "Error. Cannot parse link"
		Wirte-Host "Abortion. Exiting."
		Pause
		exit
	}
}

function menu {
	SplashMe $splashTitle
	Write-Host " "
	Write-Host " "
	Write-CatHeader
	Write-Host " "
	TypeWrite "  		 				   	 	  --WhaleLinguini"
	Write-Host " "
	Write-HyphenToEnd
	Write-Host " "
	Write-Host "Hunting for shrimps... " -NoNewLine
	Write-Host " "
	$Symbols = [string[]]('|','/','-','\')
	$SymbolIndex = [byte] 0
	$Job = Start-Job -ScriptBlock { Start-Sleep -Seconds 3 }
	while ($Job.'JobStateInfo'.'State' -eq 'Running') {
		if ($SymbolIndex -ge $Symbols.'Count') {$SymbolIndex = [byte] 0}
		Write-Host -NoNewline -Object ("{0}`b" -f $Symbols[$SymbolIndex++])
		Start-Sleep -Milliseconds 200
	}


	$myTitle = "Crypto and Tor Script Thing" # Menu Title .... pretty obvi
	$MenuOptions = @("[1]. Electrum", "[2]. Monero", "[3]. Tor Browser", "[0]. EMERGENCY EXIT") # setup your menu options here. 0 is hard coded to be exit as well.

	$conersChar = "#" 	# Corners of Menu
	$lineChar = "~" 	# Horizontal Lines
	$sideChar = "|" 	# Vertical Lines
	$exitOption = "0"	# Set what option number (if any) for an exit option.

	Write-Message "#" "Checking enviroment ..."
	Write-Message "-" "Checking if required modules installed"
	# Set TLS version to 1.2
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	# Ensure required modules are installed
	Ensure-ModulesInstalled -ModuleNames '7Zip4PowerShell'
	Write-Message "-" "Checking paths ..."
	Test-PathEx $scriptDir

	do {
	cls

	SplashMe $splashMenu
	Write-Host "														Whales in powershell?. --Meemaw"
	Write-HyphenToEnd
	Write-Host " "
	Write-Host " "
		Show-BorderedMenuFixed -Title $myTitle -MenuOptions $MenuOptions -Width 40 -Height 40
		
		$choice = Read-Host "Enter your choice"
		switch ($choice) {
			"exit" { exit }
			$exitOption { exit }
			default {
				if ($MenuOptions -and $choice -ge 1 -and $choice -le $MenuOptions.Count) {
					$selectedOption = $MenuOptions[$choice - 1]
					Write-Host "Selected option: $selectedOption"
					launchWhales $choice
				} else {
					Write-Host "Please select a valid option"
				}
			}
		}
		Write-Host "`nPress any key to continue..."
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	} while ($choice -ne "exit")

}

$keyPressed = Countdown -seconds 3

# If a key was pressed, run the menu; otherwise, run RunAsTool.exe
if ($keyPressed) {
#Write-Host "Key Pressed"
menu
} else {
#Write-Host "No Key"
    RunAsTool
}
