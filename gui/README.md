# GUI Dashboard

This directory contains an optional local Streamlit dashboard for presentation demos.

It is intentionally lightweight:

- local-only
- presentation-focused
- uses existing repo scripts and `kubectl`
- not a production portal

## Start Command

```bash
conda activate cloud
streamlit run gui/app.py --server.address 127.0.0.1 --server.port 8501
```

Open:

```text
http://127.0.0.1:8501
```

## What It Shows

- cluster overview
- tenant resource overview
- generated kubeconfig filenames
- automation buttons for the existing scripts
- latest test-results viewer
- presentation checklist

## Safety Notes

- the app is intended to bind to `127.0.0.1` only
- it does not expose private key contents
- it does not include cluster deletion buttons
- it does not include tenant offboarding buttons by default
