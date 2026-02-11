#!/usr/bin/env bash
# Validate R code: install dependencies, lint, and run tests.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "--- :gear: Setup r2u repository and R"
# Install prerequisites
apt-get update
apt-get install -y wget ca-certificates gnupg

# Add r2u GPG key
wget -q -O- https://eddelbuettel.github.io/r2u/assets/dirk_eddelbuettel_key.asc \
  | tee /etc/apt/trusted.gpg.d/cranapt_key.asc > /dev/null

# Add r2u repository (pre-compiled CRAN binaries)
echo "deb [arch=amd64] https://r2u.stat.illinois.edu/ubuntu noble main" \
  | tee /etc/apt/sources.list.d/cranapt.list

# Add CRAN GPG key
wget -q -O- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
  | tee /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc > /dev/null

# Add CRAN repository
echo "deb [arch=amd64] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
  | tee /etc/apt/sources.list.d/cran_r.list

# Configure apt to prefer r2u packages
echo -e "Package: *\nPin: release o=CRAN-Apt Project\nPin: release l=CRAN-Apt Packages\nPin-Priority: 700" \
  | tee /etc/apt/preferences.d/99cranapt

# Update and install R
apt-get update
apt-get install -y r-base-core

echo "--- :gear: Setup bspm for binary package installs"
# Install Python dependencies for bspm
apt-get install -y python3-dbus python3-gi python3-apt

# Install bspm
Rscript -e 'install.packages("bspm", repos="https://cloud.r-project.org")'

# Enable bspm system-wide
R_HOME=$(R RHOME)
echo 'suppressMessages(bspm::enable())' | tee -a "${R_HOME}/etc/Rprofile.site"
echo 'options(bspm.version.check=FALSE)' | tee -a "${R_HOME}/etc/Rprofile.site"

echo "--- :package: Install R dependencies"
# Install lintr via apt (fast binary install)
apt-get install -y r-cran-lintr

# Install project dependencies
make install-deps

echo "--- :white_check_mark: Run validation"
make validate

echo "--- :test_tube: Run tests"
make test
