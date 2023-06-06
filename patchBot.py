import getpass
import json
import re
import os
import requests
from bs4 import BeautifulSoup
from requests.auth import HTTPBasicAuth
# from http.cookiejar import MozillaCookieJar
from cryptography.fernet import Fernet
import logging


# Enable debug logging if switch is True
DEBUG_LOGGING = False

# Configure logging
logging.basicConfig(level=logging.DEBUG if DEBUG_LOGGING else logging.INFO,
                    format='[%(levelname)s] %(message)s')

def encrypt_value(key, value):
    f = Fernet(key)
    encrypted_value = f.encrypt(value.encode())
    return encrypted_value

def decrypt_value(key, encrypted_value):
    f = Fernet(key)
    decrypted_value = f.decrypt(encrypted_value).decode()
    return decrypted_value

def generate_encryption_key(key_file):
    if os.path.exists(key_file):
        key = open(key_file, "rb").read()
    else:
        key = Fernet.generate_key()
        with open(key_file, "wb") as f:
            f.write(key)
    return key

def get_my_oracle_support_credential():
    user_file = ".user"
    secure_password_file = ".credentials"
    key_file = ".encryptkey"

    key = generate_encryption_key(key_file)

    if not os.path.exists(user_file):
        username = input("Enter your MOS Username: ")
        with open(user_file, "wb") as f:
            encrypted_username = encrypt_value(key, username)
            f.write(encrypted_username)

    if not os.path.exists(secure_password_file):
        password = getpass.getpass("Enter your MOS Password: ")
        with open(secure_password_file, "wb") as f:
            encrypted_password = encrypt_value(key, password)
            f.write(encrypted_password)

    encrypted_username = open(user_file, "rb").read()
    encrypted_password = open(secure_password_file, "rb").read()

    username = decrypt_value(key, encrypted_username)
    password = decrypt_value(key, encrypted_password)

    return username, password

def get_my_oracle_support_session(username, password):
    location = None
    cookie_file = "mos.cookie"
    # eat any old cookies
    if os.path.exists(cookie_file):
        os.remove(cookie_file)

    try:
        # Create a session and update headers
        session = requests.session()
        session.headers.update({'User-Agent': 'Mozilla/5.0'})

        # Initiate updates.oracle.com request to get login redirect URL
        logging.debug('Requesting downloads page')
        r = session.get("https://updates.oracle.com/Orion/Services/download", allow_redirects=False)
        login_url = r.headers['Location']
        if not login_url:
            logging.error("Location was empty so login URL can't be set") 
            exit(2)

        # Create a NEW session, then send Basic Auth to login redirect URL
        logging.debug('Sending Basic Auth to login, using new session')
        session = requests.session()
        logging.debug("Using MOS username: " + username)
        r = session.post(login_url, auth = HTTPBasicAuth(username, password))
            
                # Validate login was success                 
        if r.ok:
            logging.debug("MOS login was successful")
            return session
        else:
            logging.error("MOS login was NOT successful.")
            exit(2)
    except:
        logging.error("Issue getting MOS auth token")
        raise

def get_latest_patch_number(session, product, release, platform, description=None):
    search_url = f"https://updates.oracle.com/Orion/AdvancedSearch/process_form?product={product}&release={release}&plat_lang={platform}&description={description}"
    previous_patch_file = f"{product}_{release}_{platform}.txt"
    previous_patch = ""
    new_patch = False
    patch_descr = None

    if os.path.exists(previous_patch_file):
        with open(previous_patch_file, "r") as f:
            previous_patch = f.read()

    try:
        headers = {"User-Agent": "Mozilla/5.0"}
        response = session.get(search_url, headers=headers)

        soup = BeautifulSoup(response.content.decode('utf-8'), 'html.parser')
        
        # Find the results table and use the first row to look for patch
        table = soup.find('table', attrs={'summary': 'HtmlTable'})
        rows = table.find_all('tr')

        # Find Description
        match_text = 'Patchset'
        td_elements = rows[1].find_all('td')
        for td in td_elements:
            if match_text in td.text:
                patch_descr = td.text.split('Patchset')[1]
                break
        
        # Find Patch Number
        cell = None
        cell = rows[1].find('td', class_='OraTableCellNumber')
        if cell:
            latest_patch = cell.text.strip()

        # Get Platform Friendly Name - Default is Platform Code
        friendly_name = None
        friendly_name = soup.find('a', attrs={'name': 'query_link'}).text
        if friendly_name:
            platform = friendly_name.split(' : ')[1].rstrip()

        if latest_patch != previous_patch:
                new_patch = True
                with open(previous_patch_file, "w") as f:
                    f.write(latest_patch)
        else:
            latest_patch = ""

    except Exception as e:
        raise Exception(f"Error getting patches; refine your search: {search_url}")

    return new_patch, latest_patch, patch_descr + ' (' + platform + ')'


def set_slack_notification(webhook_url, message, username, channel):
    body = {
        "text": message,
        "channel": channel,
        "username": username
    }
    headers = {"Content-Type": "application/json"}

    try:
        response = requests.post(webhook_url, data=json.dumps(body), headers=headers)
        response.raise_for_status()
    except Exception as e:
        raise Exception(f"Failed to post to Slack: {e}")


def find_latest_mos_patch(product, release, platform, description=None, notify=None, webhook_url=None, username=None, channel=None):
    username, password = get_my_oracle_support_credential()
    session = get_my_oracle_support_session(username, password)

    if session:
        new_patch, patch, descr = get_latest_patch_number(session, product, release, platform, description)

        if new_patch:
            message = f"*{descr}* is available: `{patch}`"
            # mosbot = f"/mos patch {patch}"
            if notify == "slack":
                set_slack_notification(webhook_url, message, username, channel)
                # set_slack_notification(webhook_url, mosbot, username, channel)
            elif notify == "teams":
                # Future implementation for Microsoft Teams
                pass
            else:
                print(message)



