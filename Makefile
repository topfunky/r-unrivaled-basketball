# Purpose: Automates running the Unrivaled Basketball League analysis scripts
# to generate rankings and ELO rating visualizations.

# Default target
all: rankings elo wp

# Generate rankings visualization
rankings: task03.R
	Rscript task03.R

# Generate ELO ratings visualization
elo: task04.R
	Rscript task04.R

wp: task09.R
	Rscript task09.R

# Run all task files
all-tasks: task02 rankings elo task06 task07 pbp wp

# Individual task targets
task01: task01.R
	Rscript task01.R

task02: task02.R
	Rscript task02.R

task06: task06.R
	Rscript task06.R

task07: task07.R
	Rscript task07.R

pbp: task08.R
	Rscript task08.R

# Clean up generated files
clean:
	rm -f unrivaled_rankings_3.png unrivaled_rankings_3.feather
	rm -f unrivaled_elo_ratings.png unrivaled_elo_rankings.feather
	rm -f plots/*.png
	rm -f *.feather

# Install required R packages
install-deps:
	Rscript install_dependencies.R

# Set up git hooks
setup-hooks:
	@echo "Setting up git hooks..."
	@mkdir -p .git/hooks
	@rm -f .git/hooks/pre-commit
	@ln -s ../../hooks/pre-commit .git/hooks/pre-commit
	@chmod +x hooks/pre-commit
	@echo "✨ Git hooks set up successfully!"

# List all available tasks
list:
	@echo "Available tasks:"
	@echo ""
	@echo "  all          - Generate rankings, ELO ratings, and win probability model (default)"
	@echo "  rankings     - Generate team rankings visualization"
	@echo "  elo          - Generate ELO ratings visualization"
	@echo "  wp           - Generate win probability model and visualizations"
	@echo ""
	@echo "  all-tasks    - Run all task files in sequence (task02, rankings, elo, task06, task07, pbp, wp)"
	@echo ""
	@echo "  task01       - Generate initial data analysis and visualizations"
	@echo "  task02       - Scrape and process game data"
	@echo "  task06       - Generate player statistics"
	@echo "  task07       - Process and analyze game events"
	@echo "  pbp          - Generate play-by-play analysis"
	@echo ""
	@echo "  clean        - Remove all generated files (plots, data files)"
	@echo "  install-deps - Install required R packages"
	@echo "  setup-hooks  - Set up git hooks for code formatting"
	@echo "  list         - Show this help message"

.PHONY: all rankings elo wp all-tasks task01 task02 task06 task07 pbp clean install-deps setup-hooks list
