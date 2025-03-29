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

# Clean up generated files
clean:
	rm -f unrivaled_rankings_3.png unrivaled_rankings_3.feather
	rm -f unrivaled_elo_ratings.png unrivaled_elo_rankings.feather

# Install required R packages
install-deps:
	Rscript -e 'install.packages(c("tidyverse", "ggplot2", "lubridate", "ggbump", "elo", "devtools", "feather"), repos="https://cloud.r-project.org/")'
	Rscript -e 'devtools::install_github("topfunky/gghighcontrast")'

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
	@echo "  all      - Generate both rankings and ELO ratings (default)"
	@echo "  rankings - Generate only the rankings visualization"
	@echo "  elo      - Generate only the ELO ratings visualization"
	@echo "  clean    - Remove all generated files"
	@echo "  install-deps  - Install required R packages"
	@echo "  setup-hooks   - Set up git hooks"
	@echo "  list     - Show this help message"

.PHONY: all rankings elo clean install-deps setup-hooks list
