"""Minimal Replicate REST client: file upload + blocking prediction. Needs REPLICATE_API_TOKEN."""
import json, os, sys, time, urllib.error, urllib.request, uuid

TOKEN = os.environ.get("REPLICATE_API_TOKEN") or sys.exit("REPLICATE_API_TOKEN is not set")
H = {"Authorization": f"Bearer {TOKEN}"}


def upload(path):
    b = uuid.uuid4().hex
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"content\"; filename=\"{os.path.basename(path)}\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + open(path, "rb").read() + f"\r\n--{b}--\r\n".encode()
    req = urllib.request.Request("https://api.replicate.com/v1/files", data=body, method="POST",
                                 headers={**H, "Content-Type": f"multipart/form-data; boundary={b}"})
    return json.load(urllib.request.urlopen(req))["urls"]["get"]


def predict(model, inp):
    """Run `model` with `inp`; returns the prediction record (`output`, `id`, `metrics`). Retries 429s."""
    body = json.dumps({"input": inp}).encode()
    for attempt in range(6):
        req = urllib.request.Request(f"https://api.replicate.com/v1/models/{model}/predictions", data=body, method="POST",
                                     headers={**H, "Content-Type": "application/json", "Prefer": "wait"})
        try:
            d = json.load(urllib.request.urlopen(req, timeout=600))
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(5 * (attempt + 1)); continue
            sys.exit(f"{model}: HTTP {e.code} {e.read()[:500]}")
        while d.get("status") in ("starting", "processing"):
            time.sleep(2)
            d = json.load(urllib.request.urlopen(urllib.request.Request(d["urls"]["get"], headers=H)))
        if d.get("status") != "succeeded":
            sys.exit(f"{model}: {d.get('status')} {d.get('error')}")
        return d
    sys.exit(f"{model}: rate limited repeatedly")


def fetch(url):
    return urllib.request.urlopen(url).read()
