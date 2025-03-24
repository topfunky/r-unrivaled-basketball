# r-unrivaled-basketball

An experiment in charting basketball rankings, coded with https://www.cursor.com

Article and charts at https://topfunky.com/2025/unrivaled-elo/

![Season rankings](https://topfunky.com/2025/unrivaled-elo/unrivaled_rankings_3.out.png)

## Development Setup

### Git Hooks

This repository uses pre-commit hooks to format R files. To set up:

1. Create a symlink to the pre-commit hook:
   ```bash
   ln -s hooks/pre-commit .git/hooks/pre-commit
   ```
1. Make the hook executable:
   ```bash
   chmod +x .git/hooks/pre-commit
   ```
