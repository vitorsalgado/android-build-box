FROM ubuntu

ENV DEBIAN_FRONTEND noninteractive

# ------------------------------------------------------
# --- OpenJDK 8

RUN apt-get update && apt-get install -y wget git curl zip software-properties-common && \
    add-apt-repository ppa:openjdk-r/ppa && \
    apt-get update && apt-get install -y openjdk-7-jdk openjdk-8-jdk

ENV JAVA7_HOME /usr/lib/jvm/java-7-openjdk-amd64
ENV JAVA8_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV JAVA_HOME $JAVA8_HOME
ENV JAVA_TOOL_OPTIONS "-Dfile.encoding=UTF8"




# ------------------------------------------------------
# --- Android

ENV GRADLE_VERSION gradle-4.1-all
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -yq libstdc++6:i386 zlib1g:i386 libncurses5:i386 lib32z1 ant maven expect --no-install-recommends
ENV GRADLE_URL http://services.gradle.org/distributions/${GRADLE_VERSION}.zip
RUN curl -L ${GRADLE_URL} -o /tmp/${GRADLE_VERSION}.zip && unzip /tmp/${GRADLE_VERSION}.zip -d /usr/local && rm /tmp/${GRADLE_VERSION}.zip
ENV GRADLE_HOME /usr/local/${GRADLE_VERSION}

ENV ANDROID_SDK_URL http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz

RUN curl -L ${ANDROID_SDK_URL} | tar xz -C /usr/local

ENV ANDROID_HOME /usr/local/android-sdk-linux
RUN chmod -R +w $ANDROID_HOME
ENV ANDROID_SDK_DATE 20170206
ENV ANDROID_SDK_COMPONENTS platform-tools,build-tools-27.0.1,android-27,extra-android-m2repository,extra-google-m2repository

ADD android-accept-licenses.sh /opt/tools/android-accept-licenses.sh

RUN chmod +x /opt/tools/android-accept-licenses.sh
RUN mkdir ${ANDROID_HOME}/licenses && echo 8933bad161af4178b1185d1a37fbf41ea5269c55 > ${ANDROID_HOME}/licenses/android-sdk-license
RUN ["sh", "-c", "/opt/tools/android-accept-licenses.sh \"${ANDROID_HOME}/tools/android update sdk --no-ui --all --filter ${ANDROID_SDK_COMPONENTS}\""]

ENV PATH $PATH:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools:${GRADLE_HOME}/bin




# ------------------------------------------------------
# --- OS Packages

RUN apt-get update && \
    apt-get install -y g++ \
    automake \
    autoconf \
    gcc \
    groff \
    libc6-dev \
    libgmp-dev \
    libmpc-dev \
    libmpfr-dev \
    m4 \
    rsync \
    unzip \
    ncurses-dev \
    ocaml \
    autoconf-archive \
    libtool \
    libboost-all-dev \
    libevent-dev \
    libdouble-conversion-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    liblz4-dev \
    liblzma-dev \
    libsnappy-dev \
    make \
    binutils-dev \
    libjemalloc-dev \
    libssl-dev \
    python3 \
    pkg-config \
    python-software-properties \
    libiberty-dev \
    zlib1g-dev \
    libjsoncpp-dev && \
    git clone https://github.com/facebook/redex /redex




# ------------------------------------------------------
# --- Redex

ENV LD_LIBRARY_PATH /usr/local/lib
ENV ANDROID_SDK $ANDROID_HOME

WORKDIR /redex

RUN git submodule update --init && \
    autoreconf -ivf && ./configure && make && make install




# ------------------------------------------------------
# --- Infer

ENV OPAM_VERSION 1.2.2

RUN curl -sL \
    https://github.com/ocaml/opam/releases/download/$OPAM_VERSION/opam-${OPAM_VERSION}-x86_64-Linux \
    -o /usr/local/bin/opam && \
    chmod 755 /usr/local/bin/opam && \
    ((/usr/local/bin/opam --version | grep -q $OPAM_VERSION) || \
    (echo "failed to download opam from GitHub."; exit 1)) && \
    opam init -y --comp=4.02.3

ENV INFER_VERSION v0.8.1

RUN cd /opt && \
    curl -sL \
    https://github.com/facebook/infer/releases/download/${INFER_VERSION}/infer-linux64-${INFER_VERSION}.tar.xz | \
    tar xJ && \
    rm -f /infer && \
    ln -s ${PWD}/infer-linux64-$INFER_VERSION /infer

WORKDIR /infer

RUN opam install -y extlib.1.5.4 atdgen.1.6.0 javalib.2.3.1 sawja.1.5.1 && \
    eval $(opam config env) && \
    opam update && \
    opam pin add --yes --no-action infer . && \
    opam install --deps-only infer && \
    eval $(opam config env) && \
    ./build-infer.sh

ENV INFER_HOME /infer/infer
ENV PATH ${INFER_HOME}/bin:${PATH}




# ------------------------------------------------------
# --- Ruby + Fastlane

RUN apt-get update && \
    apt-get install -y ruby-full && \
    gem install bundler && \
    gem install fastlane --no-document \
    && fastlane --version




# ------------------------------------------------------
# --- Google Gloud SDK

RUN echo "deb https://packages.cloud.google.com/apt cloud-sdk-`lsb_release -c -s` main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
RUN sudo apt-get update -qq \
    && sudo apt-get install -y -qq google-cloud-sdk

ENV GCLOUD_SDK_CONFIG /usr/lib/google-cloud-sdk/lib/googlecloudsdk/core/config.json

RUN /usr/bin/gcloud config set --installation component_manager/disable_update_check true \
    && sed -i -- 's/\"disable_updater\": false/\"disable_updater\": true/g' $GCLOUD_SDK_CONFIG \
    && /usr/bin/gcloud config set --installation core/disable_usage_reporting true \
    && sed -i -- 's/\"disable_usage_reporting\": false/\"disable_usage_reporting\": true/g' $GCLOUD_SDK_CONFIG




# ------------------------------------------------------
# --- Cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*