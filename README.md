# patchbot for My Oracle Support

patchBot is a set of Powershell and Python functions to make it easy to watch for new releases on My Oracle Support. Call `Find-LatestMOSPatch` or `find_latest_mos_patch` and patchBot will look for the latest patch release. If the release is newer than the last run, it can notify you that a new patch is available.

*Powershell Example*

```powershell
git clone https://github.com/psadmin-io/patchBot.git; cd patchBot
. .\patchbot.ps1

# Look for the latest HR Image on Linux (Native OS)
Find-LatestMOSPatch -Product '21858' `
                    -Platform '226P' `
                    -Release '27001300090200' `
                    -Description 'PEOPLESOFT%25UPDATE%25NATIVE+OS' `
                    -Notify 'slack' `
                    -WebHookURL 'https://hooks.slack.com/services/<TOKEN>' `
                    -Username '<slack username>' `
                    -Channel '<slack channel>'
```

*Python Example*

First, install Python modules with `pip`.

```bash
git clone https://github.com/psadmin-io/patchBot.git && cd patchBot
python3 -m pip install -r requirements.txt
```

Then, create a python script to call `patchBot` and search for your patches.

```python
from patchBot import find_latest_mos_patch

# Look for the latest HR Image on Linux (Native OS)
find_latest_mos_patch("21858", "27001300090200", "226P", "PEOPLESOFT%25UPDATE%25NATIVE+OS")

# With Slack Notification
find_latest_mos_patch("21858", "27001300090200", "226P", "PEOPLESOFT%25UPDATE%25NATIVE+OS", "slack", "https://hooks.slack.com/services/TOKEN", "slackusername", "slackchannel")
```

`patchBot` will store the last patch returned from MOS in the current working directory in a `.txt` file. It uses that patch number to compare against future runs to determine if a new patch was released.

There is also `slack.py` that shows how to load a list of products and releases from YAML and check for updates.

## Parameters for Find-LatestMOSPatch

There are 3 required fields: `Product`, `Release`, and `Platform`. Below are some examples of the values you can use to search for PeopleSoft releases.

If you want to search for products that don't have values listed here, you can use the [MOS Advanced Patch](https://updates.oracle.com/Orion/AdvancedSearch/process_form) search page to refine your search. The query string will show the values you can use for other searches.

*Required*

* `Product`: 
  * PeopleSoft HCM: `21858`
  * PeopleSoft FSCM: `21707`
  * PeopleSoft ELM: `21612`
  * PeopleSoft CS: `21591`
  * PeopleSoft CRM: `21523`
  * PeopleSoft Cloud Manager (IH): `38378`
  * PeopleTools: `21917` (or `21918`)
  
* `Release`: 
  * PeopleSoft 9.2 (Applications): `27001300090200`
  * Cloud Manager: `27001300090100`
  * PeopleTools 8.58: `600000000115152`
  * PeopleTools 8.59: `600000000156683`
  * PeopleTools 8.60: `600000000171694`

* `Platform`
  * Windows: `233P`
  * Linux: `226P`
  * HP-UX: `197P`
  * AIX: `212P`

> To find the codes for your product or platform, you can use the [Advanced Search](https://updates.oracle.com/Orion/AdvancedSearch/process_form) page to select your criteria and then look in the URL to grab the codes.

*Optional*

* `Description`: Use the description field to narrow down patches you want to watch. `patchBot` will take the top result so you can often use the description field to filter out patches you want to ignore. For example, if you want notifications for PeopleTools patch releases, the PeopleTools product will give you results that include the ELK DPK and other various patches. Use the description `%25Product%25Patch%25DPK` to only return the PeopleTools Patches. The description should be URL encoded (the string is added to the end of the MOS search). To filter for PeopleSoft Image releases, you can use the description `PEOPLESOFT%25UPDATE%25NATIVE+OS`.
* `Notify`: Currently, only Slack notifications are supported. If you pass in the value `slack`, you need to provide the `WebhookURL`, `Username` and `Channel` parameters.
  
## MOS Credentials

`patchBot` can store your MOS credentials to file so it can be scripted and set to run on a schedule. The MOS Username is stored in `.user` and the password is hashed and stored in `.credentials`. 

The first time you run `patchBot`, it will prompt you to enter the MOS credentials to use. To change the password, delete the `.credentials` file and re-run `patchBot`.

## Tips

Some searches might include the same product and release and only the description changes (e.g, PeopleTools Patches and the Infrastructure DPK). `patchBot` uses the product and release in the storage file, so you the patch numbers will overwrite each other. To get around this, run `patchBot` in different folders to separate your storage.

```powershell
set-location $PATCHBOT_BASE\pt 

# PeopleTools - 8.58
Find-LatestMOSPatch -Product '21918' `
                    -Platform '226P' `
                    -Release '600000000115152' `
                    -Description '%25Product%25Patch%25DPK'

set-location $PATCHBOT_BASE\infra

# PeopleTools - 8.58 - INFRA-DPK
Find-LatestMOSPatch -Product '21918' `
                    -Platform '226P' `
                    -Release '600000000115152' `
                    -Description '%INFRA%'
```

When you do this, you will need to copy your `.user` and `.credential` (and `.encryptkey` for Python) files to the subfolder for MOS authentication.