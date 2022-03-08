#---------------------------------------------------------[Initialization]--------------------------------------------------------

# Valid values: "Stop", "Inquire", "Continue", "Suspend", "SilentlyContinue"
$ErrorActionPreference = "Stop"
$DebugPreference = "SilentlyContinue"
$VerbosePreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#------------------------------------------------------------[Functions]----------------------------------------------------------

Function Get-MyOracleSupportCredential {
    Begin {
        $userFile = ".user"
        $securePasswordFile = ".credentials"

        if( !( Get-Item -Path ${userFile} -ErrorAction Ignore ) ){
            Write-Host "Enter your MOS Username: " -Foreground Black -Background Yellow
            read-host | out-file ${userFile}
        }

        if( !( Get-Item -Path ${securePasswordFile} -ErrorAction Ignore ) ){
            Write-Host "Enter your MOS Password: " -Foreground Black -Background Yellow
            read-host -assecurestring  | convertfrom-securestring | out-file ${securePasswordFile}
        }
    }
    Process {

        ${user} = Get-Content ${userFile} 
        ${pass} = Get-Content ${securePasswordFile} | convertto-securestring 
        # Write-Output "User: ${user} Pass: ${pass}"
        ${mosuser} = new-object -typename System.Management.Automation.PSCredential -argumentlist ${user},${pass} 

        Return ${mosuser}
    }
}

# Function from Andy Dorfman
Function Get-MyOracleSupportSession {
  [CmdletBinding(DefaultParameterSetName='Anonymous')]

  Param (
      [Parameter(Position = 0, Mandatory = $True, ParameterSetName = 'Credential')][System.Management.Automation.PSCredential]${Credential}
  )

  Begin {
      ${ProgressPreference} = 'SilentlyContinue'

      If (${PsCmdlet}.ParameterSetName -ne "Anonymous") {
          If (${PsCmdlet}.ParameterSetName -eq "Credential" -and ${Credential} -ne [System.Management.Automation.PSCredential]::Empty) {
              ${Username} = ${Credential}.UserName
              ${Password} = ${Credential}.GetNetworkCredential().Password
          }
      }
      ${MyOracleSupportSession} = $Null
      ${RequestBody} = "ssousername=$([System.Net.WebUtility]::UrlEncode(${Username}))&password=$([System.Net.WebUtility]::UrlEncode(${Password}))"
  }

  Process {
      # Discover the URL of the authenticator
      ${Location} = [System.Uri](
          (
              (
                  Invoke-WebRequest `
                      -Uri "https://updates.oracle.com/Orion/Services/metadata?table=aru_platforms" `
                      -UserAgent "Mozilla/5.0" `
                      -UseBasicParsing `
                      -MaximumRedirection 0 `
                      -ErrorAction SilentlyContinue `
                  | Select-Object -ExpandProperty RawContent
              ).toString() -Split '[\r\n]' | Select-String "Location"
          ).ToString() -Split ' '
      )[1]

      # Acquire MOS session
      Invoke-WebRequest `
          -Uri ${Location}.AbsoluteUri `
          -UserAgent "Mozilla/5.0" `
          -UseBasicParsing `
          -SessionVariable MyOracleSupportSession `
          -Method Post `
          -Body ${RequestBody} `
      | Out-Null

      # IF OAM_ID cookie is present => authentication succeeded
      If ($(${MyOracleSupportSession}.Cookies.GetCookieHeader("$(${Location}.Scheme)://$(${Location}.Host)") | Select-String "OAM_ID=").Matches.Success) {
          Return ${MyOracleSupportSession}
      } Else {
          Throw "Authentication request failed for ${UserName}"
      }
  }

}

Function Get-LatestPatchNumber {
    [CmdletBinding()]
  
    Param(
        [Parameter(Mandatory = $True)][Microsoft.PowerShell.Commands.WebRequestSession] ${session},
        [Parameter(Mandatory = $True)][String] ${Product},
        [Parameter(Mandatory = $True)][String] ${Release},
        [Parameter(Mandatory = $True)][String] ${Platform},
        [Parameter(Mandatory = $False)][String] ${Description}
    )

    Begin {
        $searchURL="https://updates.oracle.com/Orion/AdvancedSearch/process_form?product=${Product}&release=${Release}&plat_lang=${Platform}&description=${Description}"
    }

    Process {
        $prevousPatchFile = "${Product}_${Release}_${Platform}.txt" 
        $previousPatch = get-content $prevousPatchFile -ErrorAction SilentlyContinue
        Write-Verbose "Previous Patch: ${previousPatch}"

        Write-Verbose "Search URL: ${searchURL}"
        $patchPage = Invoke-WebRequest -Uri $searchURL `
                                       -UserAgent "Mozilla/5.0" `
                                       -WebSession ${session} `
                                       -UseBasicParsing

        try {
            

            # Look for 'Patchset' in a table; the text exists in lists, but the patch we want is in a table
            $patchResults = ( 
                    $patchPage | Select-Object -ExpandProperty RawContent
                ).toString() -Split '[\r\n]' | Select-String "OraTableCellText.*Patchset"

            if ($patchResults) {
                Write-Verbose "Parsing all patch results"

                # Grab the link, and the first parameters of the link (patch_num)
                $latestPatch = 
                (
                    (
                        $patchPage.links.href | select-string "^/Orion"
                    ) -split '[&=]'
                )[1]
                Write-Verbose "Latest Patch Number: ${latestPatch}"

                # Parse the results by splitting on 'Patchset', grab the first result and grab the Title
                $patchset = 
                    ( 
                        (
                            $patchResults -split 'Patchset<br>'
                        )[1].ToString() -split '</td>'
                    )[0]
                Write-Verbose "Latest Patchset: ${patchset}"
            } else {
                Write-Verbose "No patches found"
                $latestPatch = ""
                $patchset = ""
            }
            
        }
        catch {
           Write-Verbse "Error getting patches; refine your search: $searchURL"
        }
        
        # Compare to last patch
        Write-Verbose "Previous: ${previousPatch} | Current: ${latestPatch}"
        if ($latestPatch -eq $previousPatch){
            $newPatch = $false
        } else {
            $latestPatch | out-file $prevousPatchFile
            $newPatch = $true
        }

        Return $newPatch, $latestPatch, $patchset
    }
}

Function Set-SlackNotification {
    [CmdletBinding()]
  
    Param(
        [Parameter(Mandatory = $True)][String] ${WebHookURL},
        [Parameter(Mandatory = $True)][String] ${Message},
        [Parameter(Mandatory = $True)][String] ${Username},
        [Parameter(Mandatory = $True)][String] ${Channel}
    ) 
    Begin {

    }
    Process {

        $body = @{ 
                    text=${Message}; 
                    channel=${Channel}; 
                    username=${Username}; 
                    icon_emoji=${Emoji}; 
                    icon_url=${IconUrl} 
                } | ConvertTo-Json

        Invoke-WebRequest -Method Post `
                          -Uri ${WebHookURL} `
                          -Body ${body}

    }
}

Function Find-LatestMOSPatch {
    [CmdletBinding()]
  
    Param(
        [Parameter(Mandatory = $True)][String] ${Product},
        [Parameter(Mandatory = $True)][String] ${Release},
        [Parameter(Mandatory = $True)][String] ${Platform},
        [Parameter(Mandatory = $False)][String] ${Description},
        [Parameter(Mandatory = $False)][String] ${Notify},
        [Parameter(Mandatory = $False)][String] ${WebHookURL},
        [Parameter(Mandatory = $False)][String] ${Username},
        [Parameter(Mandatory = $False)][String] ${Channel}
    ) 
    Begin {

    }
    Process {

        ${mosuser} = Get-MyOracleSupportCredential
        ${session} = Get-MyOracleSupportSession -Credential ${mosuser}

        if (${session}) {
            # HR Image - Linux Native OS
            ${new}, ${patch}, ${descr} = Get-LatestPatchNumber -Session ${session} `
                                                        -Product ${Product} `
                                                        -Release ${Release} `
                                                        -Platform ${Platform} `
                                                        -Description ${Description}

            if (${new}) {

                ${Message} = "${descr} is available: ${patch}"

                switch (${Notify}) {
                    'slack' { 
                        Write-Verbose "Posting to Slack: ${Message}"
                        Set-SlackNotification -WebHookUR ${WebHookURL} `
                                            -Message ${Message} `
                                            -Username ${Username} `
                                            -Channel ${Channel}
                     }
                    'teams' { 
                        #future
                    }
                    Default {
                        Write-Output "${Message}"
                    }
                }
                
            } else {
                Write-Verbose "No new patches"
            }
        }

    }
}