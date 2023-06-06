# Load the patchBot functions
from patchBot import find_latest_mos_patch

# Look for the latest HR Image on Linux (Native OS)
find_latest_mos_patch("21858", "27001300090200", "226P", "PEOPLESOFT%25UPDATE%25NATIVE+OS")

# With Slack Notification
# find_latest_mos_patch("21858", "27001300090200", "226P", "PEOPLESOFT%25UPDATE%25NATIVE+OS", "slack", "https://hooks.slack.com/services/TOKEN", "slackusername", "slack channel")
