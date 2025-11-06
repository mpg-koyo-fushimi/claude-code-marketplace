#!/bin/bash

osascript -e 'display notification "Claude Codeが許可を求めています" with title "Claude Code" subtitle "確認待ち" sound name "Glass"'

# Exit successfully (don't block the action)
exit 0
