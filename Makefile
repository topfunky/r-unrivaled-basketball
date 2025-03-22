# Define the R script
RSCRIPT = scrape_and_chart.R

# Define the output files
DATA_OUTPUT = game_data.feather
PLOT_OUTPUT = unrivaled_bump_chart.png

# Default target
all: install-packages

# Target to run the R script
$(DATA_OUTPUT) $(PLOT_OUTPUT): $(RSCRIPT)
	Rscript $(RSCRIPT)

# Task to install dependencies
install_deps:
	Rscript -e "options(repos = c(CRAN = 'https://cran.rstudio.com'))" -e "install.packages(c('rvest', 'dplyr', 'feather', 'ggplot2', 'ggbump'))"

# Task to set CRAN mirror
set_cran_mirror:
	Rscript -e "options(repos = c(CRAN = 'https://cran.rstudio.com'))"

# Task to list all tasks
list_tasks:
	@grep -E '^[a-zA-Z_-]+:' Makefile | awk -F: '{print $$1}'

# Clean target to remove generated files
clean:
	rm -f $(DATA_OUTPUT) $(PLOT_OUTPUT)

# Install required R packages
install-packages:
	Rscript -e 'install.packages(c("tidyverse", "ggplot2", "lubridate", "gghighcontrast", "ggbump", "elo"), repos="https://cloud.r-project.org/")'

.PHONY: all clean install_deps set_cran_mirror list_tasks
