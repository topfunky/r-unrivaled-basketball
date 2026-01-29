# Purpose: Automates running the Unrivaled Basketball League analysis scripts
# to generate rankings and ELO rating visualizations.

# Default target
.DEFAULT_GOAL := list

# Run all task files in sequence (respecting dependencies)
all-tasks: scrape rankings elo standings download pbp fetch-wnba-stats shooting

# Individual task targets
analyze-rankings: analyze_sample_rankings.R
	Rscript analyze_sample_rankings.R

scrape: scrape_unrivaled_scores.R
	Rscript scrape_unrivaled_scores.R

# Generate rankings visualization
rankings: rankings_bump_chart.R
	Rscript rankings_bump_chart.R

# Generate ELO ratings visualization
elo: calculate_elo_ratings.R
	Rscript calculate_elo_ratings.R

standings: generate_standings_table.R
	Rscript generate_standings_table.R

download: download_game_data.R
	Rscript download_game_data.R

pbp: parse_play_by_play.R
	Rscript parse_play_by_play.R

wp: model_win_probability.R
	Rscript model_win_probability.R

shooting: analyze_shooting_metrics.R
	Rscript analyze_shooting_metrics.R

fetch-wnba-stats: fetch_wnba_stats.R
	Rscript fetch_wnba_stats.R

# Clean up generated files
clean:
	rm -f unrivaled_rankings_3.png unrivaled_rankings_3.feather
	rm -f unrivaled_elo_ratings.png unrivaled_elo_rankings.feather
	rm -f plots/*.png
	rm -f *.feather
	rm -f coverage-report.html
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
	@echo "  all             - Generate rankings, ELO ratings, and win probability model (default)"
	@echo "  rankings        - Generate team rankings visualization"
	@echo "  elo             - Generate ELO ratings visualization"
	@echo "  wp              - Generate win probability model and visualizations"
	@echo "  format          - Format all R files using air"
	@echo "  validate        - Validate all R files using lintr"
	@echo ""
	@echo "  all-tasks       - Run all task files in sequence"
	@echo ""
	@echo "  analyze-rankings - Generate initial data analysis and visualizations"
	@echo "  scrape          - Scrape and process game data"
	@echo "  standings       - Generate player statistics"
	@echo "  download        - Process and analyze game events"
	@echo "  pbp             - Generate play-by-play analysis"
	@echo "  shooting        - Calculate additional basketball metrics"
	@echo "  fetch-wnba-stats - Download WNBA player shooting percentages"
	@echo ""
	@echo "  clean           - Remove all generated files (plots, data files)"
	@echo "  install-deps    - Install required R packages"
	@echo "  setup-hooks     - Set up git hooks for code formatting"
	@echo "  test            - Run testthat tests"
	@echo "  coverage        - Generate test coverage report"
	@echo "  list            - Show this help message"

# Format all R files using air
format:
	@echo "Formatting all R files..."
	@find . -name "*.R" -exec air format {} \;
	@echo "Formatting complete!"

# Validate all R files using lintr
validate:
	@echo "Validating all R files..."
	@Rscript -e "lintr::lint_dir('.')"
	@echo "Validation complete!"

# Run tests using testthat
test:
	@echo "Running tests..."
	@Rscript tests/testthat.R
	@echo "Tests complete!"

# Run test coverage report
coverage:
	@echo "Running test coverage report..."
	@Rscript -e "covr::report(covr::package_coverage(type = 'tests'), file = 'coverage-report.html', browse = FALSE)"
	@echo "Coverage report saved to coverage-report.html"

# Run all task files in alphabetical order (use with caution)
run-all-tasks: format
	@echo "Running all tasks in alphabetical order (use with caution)..."
	@for file in analyze_sample_rankings.R scrape_unrivaled_scores.R rankings_bump_chart.R calculate_elo_ratings.R generate_standings_table.R download_game_data.R parse_play_by_play.R model_win_probability.R analyze_shooting_metrics.R fetch_wnba_stats.R; do \
		echo "Running $$file..."; \
		Rscript $$file; \
	done
	@echo "All tasks complete!"

.PHONY: all rankings elo wp all-tasks analyze-rankings scrape standings download pbp shooting fetch-wnba-stats clean install-deps setup-hooks list format run-all-tasks validate test coverage
