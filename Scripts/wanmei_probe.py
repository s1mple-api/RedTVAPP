#!/usr/bin/env python3
"""Read-only smoke checks for the public Wanmei CS data site's own API.

The public frontend configuration is read from the site's current JS bundle.
No login tokens, cookies, account endpoints or write operations are used.
"""
import argparse
import hashlib
import hmac
import json
import re
import secrets
import time
import urllib.parse
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo
from pathlib import Path

SITE = "https://data.wanmei.com"
API = "https://esports.wanmei.com"


def canonical(parameters, timestamp, nonce):
    values = {key: value if isinstance(value, list) else [value] for key, value in parameters.items()}
    values.update(timestamp=[timestamp], nonce=[nonce])
    return "&".join(
        urllib.parse.quote_plus(str(key), safe="-._~") + "=" + urllib.parse.quote_plus(str(value), safe="-._~")
        for key in sorted(values)
        for value in sorted(map(str, values[key]))
    )


def public_key():
    local = Path("/private/tmp/redtv-wanmei.js")
    source = local.read_text() if local.is_file() else ""
    if not source:
        html = urllib.request.urlopen(SITE + "/csgo", timeout=20).read().decode()
        script = re.search(r'src="(/asset/csgo/js/csgo-[^\"]+\.js)"', html).group(1)
        source = urllib.request.urlopen(SITE + script, timeout=20).read().decode()
    return re.search(r'Np="([a-f0-9]{64})"', source).group(1)


def request(path, parameters, key, output):
    if not path.startswith("/apg/eventcenter/csgo/"):
        raise ValueError("Only public CS data routes are allowed by this probe")
    timestamp, nonce = str(int(time.time())), secrets.token_hex(16)
    signature = hmac.new(key.encode(), canonical(parameters, timestamp, nonce).encode(), hashlib.sha256).hexdigest()
    query = urllib.parse.urlencode(parameters, doseq=True)
    req = urllib.request.Request(API + path + ("?" + query if query else ""), headers={
        "X-Timestamp": timestamp, "X-Nonce": nonce, "X-Signature": signature,
        "Origin": SITE, "Referer": SITE + "/csgo", "Accept": "application/json",
        "User-Agent": "RedTV-iOS-Integration/2.0",
    })
    with urllib.request.urlopen(req, timeout=25) as response:
        value = json.load(response)
    output.write_text(json.dumps(value, ensure_ascii=False, indent=2))
    result = value.get("result", value.get("data"))
    print(json.dumps({"file": output.name, "code": value.get("code"), "message": value.get("message"), "result": list(result)[:20] if isinstance(result, dict) else f"list({len(result)})" if isinstance(result, list) else str(result)[:150]}, ensure_ascii=False))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--path")
    parser.add_argument("--params", default="{}")
    parser.add_argument("--output", default="/private/tmp/wanmei-fixtures")
    args = parser.parse_args()
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    key = public_key()
    if args.path:
        request(args.path, json.loads(args.params), key, output / "response.json")
        return
    events = request("/apg/eventcenter/csgo/event/getEventList", {"pageNum": 1, "pageSize": 20, "darkType": 1, "type": 1}, key, output / "events.json")
    request("/apg/eventcenter/csgo/getMatchList", {"matchTime": datetime.now(ZoneInfo("Asia/Shanghai")).strftime("%Y-%m-%d") + " 00:00:00", "darkType": 1}, key, output / "matches.json")
    request("/apg/eventcenter/csgo/team/newRankList", {"searchType": 0, "id": -1}, key, output / "teams.json")
    request("/apg/eventcenter/csgo/team/rank", {"page": 1, "pageSize": 30, "type": 0}, key, output / "valve-teams.json")
    request("/apg/eventcenter/csgo/player/stats", {"pageNum": 1, "pageSize": 30, "darkType": 1}, key, output / "players.json")
    rows = (events or {}).get("eventResponse", {}).get("dtoList", [])
    if rows:
        row = rows[0]
        event_id = row.get("eventId", row.get("id"))
        if event_id:
            request("/apg/eventcenter/csgo/event/getEventDetail", {"eventId": str(event_id), "darkType": 1}, key, output / "event-detail.json")


if __name__ == "__main__":
    main()
