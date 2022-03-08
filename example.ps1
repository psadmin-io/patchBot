# Load the patchBot functions
. .\patchbot.ps1

# Look for the latest HR Image on Linux (Native OS)
Find-LatestMOSPatch -Product '21858' `
                    -Platform '266P' `
                    -Release '27001300090200' `
                    -Description 'PEOPLESOFT%25UPDATE%25NATIVE+OS' `
                    -Notify 'slack' `
                    -WebHookURL 'https://hooks.slack.com/services/<TOKEN>' `
                    -Username '<slack username>' `
                    -Channel '<slack channel>'
