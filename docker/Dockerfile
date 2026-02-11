# Purpose: R environment for CI validation and tests.
# Installs R via r2u, bspm, lintr, and project dependencies.
# Used by Cloud Build to run make validate and make test.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites for adding apt repositories
RUN apt-get update \
  && apt-get install -y --no-install-recommends wget ca-certificates gnupg \
  && rm -rf /var/lib/apt/lists/*

# Add r2u GPG key and repository (pre-compiled CRAN binaries)
RUN wget -q -O- https://eddelbuettel.github.io/r2u/assets/dirk_eddelbuettel_key.asc \
  | tee /etc/apt/trusted.gpg.d/cranapt_key.asc > /dev/null \
  && echo "deb [arch=amd64] https://r2u.stat.illinois.edu/ubuntu noble main" \
  | tee /etc/apt/sources.list.d/cranapt.list

# Add CRAN GPG key and repository
RUN wget -q -O- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
  | tee /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc > /dev/null \
  && echo "deb [arch=amd64] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
  | tee /etc/apt/sources.list.d/cran_r.list

# Configure apt to prefer r2u packages
RUN echo -e "Package: *\nPin: release o=CRAN-Apt Project\nPin: release l=CRAN-Apt Packages\nPin-Priority: 700" \
  | tee /etc/apt/preferences.d/99cranapt

# Install R, bspm dependencies, lintr, and make
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    r-base-core \
    python3-dbus \
    python3-gi \
    python3-apt \
    r-cran-lintr \
    make \
  && rm -rf /var/lib/apt/lists/*

# Install bspm and enable system-wide
RUN Rscript -e 'install.packages("bspm", repos="https://cloud.r-project.org")' \
  && R_HOME=$(R RHOME) \
  && echo 'suppressMessages(bspm::enable())' | tee -a "${R_HOME}/etc/Rprofile.site" \
  && echo 'options(bspm.version.check=FALSE)' | tee -a "${R_HOME}/etc/Rprofile.site"

# Install project R dependencies (requires Makefile and install_dependencies.R)
COPY Makefile install_dependencies.R /build/
WORKDIR /build
RUN make install-deps

# Default working directory for Cloud Build (source is mounted at /workspace)
WORKDIR /workspace
