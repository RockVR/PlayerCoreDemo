import json
from yt_dlp import YoutubeDL

# install_certifi.py
#
# sample script to install or update a set of default Root Certificates
# for the ssl module.  Uses the certificates provided by the certifi package:
#       https://pypi.org/project/certifi/

import os
import os.path
import ssl
import stat
import subprocess
import sys
import certifi

STAT_0o775 = ( stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR
             | stat.S_IRGRP | stat.S_IWGRP | stat.S_IXGRP
             | stat.S_IROTH |                stat.S_IXOTH )

def updateCertifi():
    os.environ["SSL_CERT_FILE"] = certifi.where()

def getInfo(id, cookie):
    ydl_opts = {
        "extractor_args": {'youtube': {'player_client': ['ios']}},
    }
    if cookie != "":
        ydl_opts["cookiefile"] = cookie
    print("ydl_opts", ydl_opts)
    try:
        with YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(id, download=False)
            return json.dumps(info_dict)
    except Exception as e:
        print(e, cookie)
        return json.dumps({'error': str(e)})

__name__ = "getytbinfo"
