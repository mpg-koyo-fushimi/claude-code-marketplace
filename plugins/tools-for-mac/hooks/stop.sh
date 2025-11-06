#!/bin/bash

# Display macOS notification using osascript
osascript -e 'display notification "タスクが完了しました" with title "Claude Code" subtitle "処理終了" sound name "Hero"'

# Exit successfully (don't block the stop)
exit 0
