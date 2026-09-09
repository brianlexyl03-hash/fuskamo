Runtime logs currently go to stdout only (see utils/logger.js), which is
what Docker/most hosts (Render, Railway, Fly.io) already capture and let
you tail — no local log files needed for the MVP. If you add file-based
logging later (e.g. via winston's file transport), point it at this
folder and make sure it's gitignored (already is, see .gitignore).
