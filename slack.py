# Load the patchBot functions
from patchBot import find_latest_mos_patch
import yaml
import logging
import argparse

parser = argparse.ArgumentParser(description='Notify psadmin.io Community when new Patches have been found')
parser.add_argument('-s', '--source')
parser.add_argument('-t', '--token')
args = parser.parse_args()

DEBUG_LOGGING = True
logging.basicConfig(level=logging.DEBUG if DEBUG_LOGGING else logging.INFO,
                    format='[%(levelname)s] %(message)s')

with open(f"data/{args.source}.yaml", 'r') as file:
    patches = yaml.safe_load(file)

for release_name, release_code in patches['release'].items():
  for platform_name, platform_code in patches['platform'].items():
    for product_name, product_code in patches['product'].items():
      for descr_name, descr_code in patches['descr'].items():
        logging.info(f"Searching for: {release_name} - {platform_name} - {product_name} - {descr_name}")
        find_latest_mos_patch(product_code, release_code, platform_code, descr_code, descr_name, "slack", f"https://hooks.slack.com/services/{args.token}", "patchbot", "#patchBot", False)
