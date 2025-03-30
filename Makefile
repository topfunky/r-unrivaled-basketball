# Purpose: Automates running the Unrivaled Basketball League analysis scripts
# to generate rankings and ELO rating visualizations.

# Default target
all: rankings elo wp

# Generate rankings visualization
rankings: task3.R
	Rscript task3.R

# Generate ELO ratings visualization
elo: task4.R
	Rscript task4.R

wp: task9.R
	Rscript task9.R

# Run all task files
all-tasks: task2 rankings elo task6 task7 pbp wp

# Individual task targets
task1: task1.R
	Rscript task1.R

task2: task2.R
	Rscript task2.R

task6: task6.R
	Rscript task6.R

task7: task7.R
	Rscript task7.R

pbp: task8.R
	Rscript task8.R

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
	@echo "  all-tasks    - Run all task files in sequence (task2, rankings, elo, task6, task7, pbp, wp)"
	@echo ""
	@echo "  task1        - Generate initial data analysis and visualizations"
	@echo "  task2        - Scrape and process game data"
	@echo "  task6        - Generate player statistics"
	@echo "  task7        - Process and analyze game events"
	@echo "  pbp          - Generate play-by-play analysis"
	@echo ""
	@echo "  clean        - Remove all generated files (plots, data files)"
	@echo "  install-deps - Install required R packages"
	@echo "  setup-hooks  - Set up git hooks for code formatting"
	@echo "  list         - Show this help message"

.PHONY: all rankings elo wp all-tasks task1 task2 task6 task7 pbp clean install-deps setup-hooks list
