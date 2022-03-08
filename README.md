# patchbot for My Oracle Support

patchBot is a set of Powershell functions to make it easy to watch for new releases on My Oracle Support. Call `Find-LatestMOSPatch` and patchBot will look for the latest patch release. If the release is newer than the last run, it can notify you that a new patch is available.

*Example*

```powershell
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
```

`patchBot` will store the last patch returned my MOS in the current working directory. It uses that patch number to compare against future runs to determine if a new patch was released.

## Parameters for Find-LatestMOSPatch

There are 3 required fields: `Product`, `Release`, and `Platform`. Below are some examples of the values you can use to search for PeopleSoft releases.

If you want to search for products that don't have values listed here, you can use the [MOS Advanced Patch](https://updates.oracle.com/Orion/AdvancedSearch/process_form) search page to refine your search. The query string will show the values you can use for other searches.

*Required*

* `Product`: 
  * PeopleSoft HCM: `21612`
  * PeopleSoft FSCM: `21707`
  * PeopleSoft ELM: `21612`
  * PeopleSoft CS: `21591`
  * PeopleSoft Cloud Manager: `38378`
  * PeopleTools: `21918`
  
* `Release`: 
  * PeopleSoft 9.2 (Applications): `27001300090200`
  * Cloud Manager: `27001300090100`
  * PeopleTools 8.58: `600000000115152`
  * PeopleTools 8.59: `600000000156683`
  * PeopleTools 8.60: `600000000171694`

* `Platform`
  * Windows: `233P`
  * Linux: `226P`

*Optional*

* `Description`: Use the description field to narrow down patches you want to watch. `patchBot` will take the top result so you can often use the description field to filter out patches you want to ignore. For example, if you want notifications for PeopleTools patch releases, the PeopleTools product will give you results that include the ELK DPK and other various patches. Use the description `%25Product%25Patch%25DPK` to only return the PeopleTools Patches. The description should be URL encoded (the string is added to the end of the MOS search). To filter for PeopleSoft Image releases, you can use the description `PEOPLESOFT%25UPDATE%25NATIVE+OS`.
  
## MOS Credentials

`patchBot` can store your MOS credentials to file so it can be scripted and set to run on a schedule. The MOS Username is stored in `.user` and the password is hashed and stored in `.credentials`. 

The first time you run `patchBot`, it will prompt you to enter the MOS credentials to use. To change the password, delete the `.credentials` file and re-run `patchBot`.

