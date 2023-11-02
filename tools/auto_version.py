#!/usr/bin/env python3
from datetime import datetime

# Outputs a version number to be tagged by github actions
if __name__ == "__main__":
    now = datetime.utcnow()
    modifier = int(
        (now - now.replace(hour=0, minute=0, second=0, microsecond=0)).total_seconds()
    )
    print(now.strftime(f"%-Y.%-m.%-d{modifier}"))
