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
all-tasks: task2 task3 task4 task6 task7 task8 task9

# Individual task targets
task1: task1.R
	Rscript task1.R

task2: task2.R
	Rscript task2.R

task3: task3.R
	Rscript task3.R

task4: task4.R
	Rscript task4.R

task6: task6.R
	Rscript task6.R

task7: task7.R
	Rscript task7.R

task8: task8.R
	Rscript task8.R

task9: task9.R
	Rscript task9.R

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
	@echo "  all         - Generate both rankings and ELO ratings (default)"
	@echo "  rankings    - Generate only the rankings visualization"
	@echo "  elo         - Generate only the ELO ratings visualization"
	@echo "  wp          - Generate win probability model"
	@echo "  all-tasks   - Run all task files in sequence"
	@echo "  task1-9     - Run individual task files"
	@echo "  clean       - Remove all generated files"
	@echo "  install-deps - Install required R packages"
	@echo "  setup-hooks  - Set up git hooks"
	@echo "  list        - Show this help message"

.PHONY: all rankings elo wp all-tasks task1 task2 task3 task4 task6 task7 task8 task9 clean install-deps setup-hooks list
