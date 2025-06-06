FROM pytorch/pytorch:2.2.0-cuda11.8-cudnn8-runtime

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV JUPYTER_ENABLE_LAB=yes

# Create user with same UID as host user to avoid permission issues
ARG NB_USER=jovyan
ARG NB_UID=1000
ARG NB_GID=100

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    git-lfs \
    curl \
    wget \
    build-essential \
    nodejs \
    npm \
    htop \
    vim \
    tmux \
    screen \
    sudo \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install code-server (VS Code in browser)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create user
RUN groupadd wheel -g 11 && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    useradd -m -s /bin/bash -u $NB_UID -g $NB_GID $NB_USER && \
    usermod -aG sudo $NB_USER && \
    echo "$NB_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Upgrade pip and install Python packages
RUN pip install --upgrade pip setuptools wheel

# Install JupyterLab and extensions
RUN pip install \
    jupyterlab==4.0.8 \
    jupyter-server-proxy \
    jupyterlab-git \
    jupyterlab-lsp \
    python-lsp-server[all] \
    notebook \
    ipywidgets \
    voila

# Install ML and data science packages
RUN pip install \
    # MLflow client
    mlflow==2.8.1 \
    # Data versioning
    dvc[local]==3.30.3 \
    # Database clients
    psycopg2-binary \
    pymongo \
    # Core ML libraries
    scikit-learn \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    plotly \
    bokeh \
    # Web frameworks
    fastapi \
    uvicorn \
    streamlit \
    # Additional ML libraries
    transformers \
    datasets \
    accelerate \
    tensorboard \
    wandb \
    optuna \
    # Development tools
    black \
    flake8 \
    pytest \
    pre-commit

# Install additional PyTorch libraries
RUN pip install \
    torchvision \
    torchaudio \
    lightning \
    torchmetrics

# Set up JupyterLab extensions
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build && \
    jupyter lab build --dev-build=False --minimize=False

# Configure code-server
RUN mkdir -p /home/$NB_USER/.config/code-server
COPY --chown=$NB_USER:$NB_GID code-server-config.yaml /home/$NB_USER/.config/code-server/config.yaml

# Create startup script
COPY --chown=$NB_USER:$NB_GID start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Set up home directory
RUN mkdir -p /home/$NB_USER/work && \
    chown -R $NB_USER:$NB_GID /home/$NB_USER

# Switch to user
USER $NB_USER
WORKDIR /home/$NB_USER

# Set default environment variables
ENV MLFLOW_TRACKING_URI=http://mlflow-service.mlflow:5000
ENV DVC_CACHE_DIR=/home/$NB_USER/.dvc/cache

# Expose ports
EXPOSE 8888 8080 8000

# Default command
CMD ["/usr/local/bin/start.sh"] 