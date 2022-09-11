FROM ubuntu:focal AS builder
RUN apt-get update &&  \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq \
  make \
  build-essential \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  wget \
  curl \
  llvm \
  libncursesw5-dev \
  xz-utils \
  tk-dev \
  libxml2-dev \
  libxmlsec1-dev \
  libffi-dev \
  liblzma-dev \
  git \
  ca-certificates \
  gzip \
  pigz \
  bzip2 \
  pbzip2 \
  autoconf \
  automake \
  shtool \
  coreutils \
  autogen \
  libtool \
  shtool \
  nasm


RUN useradd -d /cryptobot -u 1001 -ms /bin/bash cryptobot
RUN cd /tmp \
  && wget http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz \
  && tar xf ta-lib-0.4.0-src.tar.gz \
  && cd ta-lib \
  && ./configure --prefix=/usr \
  && make \
  && make install
USER cryptobot
ENV HOME /cryptobot
WORKDIR /cryptobot
ADD .python-version .
RUN curl https://pyenv.run | bash
ENV PYENV_ROOT="$HOME/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims/:$PATH"
RUN CONFIGURE_OPTS="--enable-shared --fno-semantic-interposition --enable-optimizations --with-lto --with-pgo" pyenv install
RUN python -m venv /cryptobot/.venv
ADD requirements.txt .
RUN /cryptobot/.venv/bin/pip install --upgrade pip setuptools wheel
# pyenv is failling to compile isal without setting C_INCLUDE_PATH
RUN C_INCLUDE_PATH=/cryptobot/.pyenv/versions/pyston-2.3.4/include/python3.8-pyston2.3/ /cryptobot/.venv/bin/pip install -r requirements.txt


FROM ubuntu:focal AS cryptobot
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq \
  xz-utils \
  gzip \
  pigz \
  bzip2 \
  pbzip2

RUN useradd -d /cryptobot -u 1001 -ms /bin/bash cryptobot
USER cryptobot
ENV HOME /cryptobot
WORKDIR /cryptobot
ENV PYENV_ROOT="$HOME/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims/:$PATH"
COPY --from=builder /cryptobot/.python-version /cryptobot/
COPY --from=builder /cryptobot/.pyenv/ /cryptobot/.pyenv/
COPY --from=builder /cryptobot/.venv/ /cryptobot/.venv/
COPY --from=builder /usr/include/ta-lib/ /usr/include-ta-lib/
COPY --from=builder /usr/bin/ta-lib-config /usr/bin/ta-lib-config
ADD app.py .
ADD lib/ lib/
ADD strategies/ strategies/
ADD utils/automated-backtesting.py utils/automated-backtesting.py
ADD utils/automated-backtesting.sh utils/automated-backtesting.sh
ADD utils/prove-backtesting.py utils/prove-backtesting.py
ADD utils/prove-backtesting.sh utils/prove-backtesting.sh
ADD utils/pull_klines.py utils/pull_klines.py
EXPOSE 5555
ENTRYPOINT ["/cryptobot/.venv/bin/python", "-u",  "app.py"]
