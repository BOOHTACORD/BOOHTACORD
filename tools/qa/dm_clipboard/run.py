"""DM acceptance uses the same owned reservation coordinator as TEXT."""
from tools.qa.clipboard_paste.run import main

if __name__ == '__main__':
    raise SystemExit(main('tools/qa/dm_clipboard/scenario.mjs', 'dm-clipboard', 'DM'))
