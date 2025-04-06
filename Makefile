# Purpose: Automates running the Unrivaled Basketball League analysis scripts
# to generate rankings and ELO rating visualizations.

# Default target
all: rankings elo wp format


# Run all task files
all-tasks: task02 rankings elo task06 task07 pbp wp task10 task11 format

# Individual task targets
task01: task01.R
	Rscript task01.R

task02: task02.R
	Rscript task02.R

# Generate rankings visualization
rankings: task03.R
	Rscript task03.R

# Generate ELO ratings visualization
elo: task04.R
	Rscript task04.R

task06: task06.R
	Rscript task06.R

task07: task07.R
	Rscript task07.R

pbp: task08.R
	Rscript task08.R

wp: task09.R
	Rscript task09.R

task10: task10.R
	Rscript task10.R

task11: task11.R
	Rscript task11.R

# Clean up generated files
clean:
	rm -f unrivaled_rankings_3.png unrivaled_rankings_3.feather
	rm -f unrivaled_elo_ratings.png unrivaled_elo_rankings.feather
	rm -f plots/*.png
	rm -f *.feather
	@echo "Cleaning temporary files..."
	@find . -name "*.Rproj.user" -type d -exec rm -rf {} +
	@find . -name ".Rproj.user" -type d -exec rm -rf {} +
	@find . -name ".RData" -type f -delete
	@find . -name ".Rhistory" -type f -delete
	@echo "Cleaning complete!"

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
	@echo "  format       - Format all R files using air"
	@echo ""
	@echo "  all-tasks    - Run all task files in sequence (task02, rankings, elo, task06, task07, pbp, wp, task10, task11)"
	@echo ""
	@echo "  task01       - Generate initial data analysis and visualizations"
	@echo "  task02       - Scrape and process game data"
	@echo "  task06       - Generate player statistics"
	@echo "  task07       - Process and analyze game events"
	@echo "  pbp          - Generate play-by-play analysis"
	@echo "  task10       - Calculate additional basketball metrics"
	@echo "  task11       - Download WNBA player shooting percentages"
	@echo ""
	@echo "  clean        - Remove all generated files (plots, data files)"
	@echo "  install-deps - Install required R packages"
	@echo "  setup-hooks  - Set up git hooks for code formatting"
	@echo "  list         - Show this help message"

# Format all R files using air
format:
	@echo "Formatting all R files..."
	@find . -name "*.R" -exec air format {} \;
	@echo "Formatting complete!"

# Run the win probability model
win_prob: format
	@echo "Running win probability model..."
	@Rscript task09.R
	@echo "Win probability model complete!"

# Run all tasks
all_tasks: format
	@echo "Running all tasks..."
	@for file in task*.R; do \
		echo "Running $$file..."; \
		Rscript $$file; \
	done
	@echo "All tasks complete!"

.PHONY: all rankings elo wp all-tasks task01 task02 task06 task07 pbp task10 task11 clean install-deps setup-hooks list format win_prob all_tasks
