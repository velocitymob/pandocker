# A simple Pandoc machine for pandoc with filters, fonts and the latex bazaar
#
# Based on :
#    https://github.com/jagregory/pandoc-docker/blob/master/Dockerfile
#    https://github.com/geometalab/docker-pandoc/blob/develop/Dockerfile
#    https://github.com/vpetersson/docker-pandoc/blob/master/Dockerfile

FROM debian:stretch-slim

# Proxy to APT cacher: e.g. http://apt-cacher-ng.docker:3142
ARG APT_CACHER

# Set the env variables to non-interactive
ENV DEBIAN_FRONTEND noninteractive
ENV DEBIAN_PRIORITY critical
ENV DEBCONF_NOWARNINGS yes

#
# Debian
#
RUN set -x && \
    # Setup a cacher to speed up build
    if [ -n "${APT_CACHER}" ] ; then \
        echo "Acquire::http::Proxy \"${APT_CACHER}\";" | tee /etc/apt/apt.conf.d/01proxy ; \
    fi; \
    apt-get -qq update && \
    apt-get -qy install --no-install-recommends \
        # for deployment
		aspell \
		spell \
		cmake \
		build-essential \
		wget \
        openssh-client \
        rsync \
        # for locales and utf-8 support
        locales \
        # latex toolchain
        lmodern \
        texlive \
        texlive-lang-english \
        texlive-lang-french \
        texlive-lang-german \
        texlive-luatex \
        texlive-pstricks \
        texlive-xetex \
        xzdec \
        # reveal (see issue #18)
        netbase \
		# dia
		dia \
        # fonts
        fonts-dejavu \
        fonts-lato \
        fonts-liberation \
        fonts-noto \
        fonts-font-awesome \    
        fonts-roboto \
        # build tools
        make \
        git \
        parallel \
        wget \
        unzip \
        # panflute requirements
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-yaml \
        # required for PDF meta analysis
        poppler-utils \
        zlibc \
        # for emojis
        librsvg2-bin \
    # clean up
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/01proxy

#
# Set Locale for UTF-8 support
# This is needed for panflute filters see :
# https://github.com/dalibo/pandocker/pull/86
#
RUN locale-gen C.UTF-8
ENV LANG C.UTF-8

#
# SSH pre-config / useful for Gitlab CI
#
RUN mkdir -p ~/.ssh && \
    /bin/echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config # See Issue #87
#
# Add local cache/. It's empty by default so this does not change the final
# image on Docker Hub.
#
# However, once warmed with make warm-cache, it can save a lots of bandwidth.
#
# RUN mkdir -p ./cache
ADD cache/ ./cache


#
# Install pandoc from upstream. Debian package is too old.
#

ADD fetch-pandoc.sh /usr/local/bin/
ARG PANDOC_VERSION=2.9.2.1
RUN echo ${PANDOC_VERSION} 
RUN fetch-pandoc.sh ${PANDOC_VERSION} ./cache/pandoc.deb   && \
    dpkg --install ./cache/pandoc.deb && \
    rm -f ./cache/pandoc.deb
#
# Pandoc filters
#

#
# Python filters
#

ADD requirements.txt ./
RUN pip3 --no-cache-dir install --find-links file://${PWD}/cache -r requirements.txt

#
# pandoc-crossref
#
# This version must correspond to the correct PANDOC_VERSION.
# See https://github.com/lierdakil/pandoc-crossref/releases to find the latest
# release corresponding to the desired pandoc version.
ARG PANDOC_CROSSREF_VERSION=0.3.6.2a
ADD fetch-pandoc-crossref.sh /usr/local/bin/
#RUN fetch-pandoc-crossref.sh ${PANDOC_VERSION} ${PANDOC_CROSSREF_VERSION} ./cache/pandoc-crossref.tar.xz 
#&& \
    # tar xf ./cache/pandoc-crossref.tar.xz && \
    # install pandoc-crossref /usr/local/bin/ && \
    # install -d /usr/local/man/man1 && \
    # install pandoc-crossref.1 /usr/local/man/man1/

# Templates

ENV TEXMFLOCAL=/usr/local/share/texmf

# Templates are installed in '/.pandoc'.
ARG TEMPLATES_DIR=/.pandoc/templates

RUN mkdir -p ${TEMPLATES_DIR} && \
    mkdir /.texlive2016 && \
    # Links for the non-existent
    ln -s ${TEXMFLOCAL} /texmf && \
    # Links for the root user
    ln -s /.pandoc /root/.pandoc && \
    ln -s ${TEXMFLOCAL} /root/texmf && \
    ln -s /.texlive2016 /root/.texlive2016

#
# eisvogel template
#
# eisvogel template

ARG EISVOGEL_REPO=https://raw.githubusercontent.com/Wandmalfarbe/pandoc-latex-template
ARG EISVOGEL_VERSION=v1.4.0
RUN wget ${EISVOGEL_REPO}/${EISVOGEL_VERSION}/eisvogel.tex -O ${TEMPLATES_DIR}/eisvogel.latex && \
    ln -s ${TEXMFLOCAL} /texmf 
    # && \
    # Links for the root user
    # ln -s /.pandoc /root/.pandoc && \
    # ln -s ${TEXMFLOCAL} /root/texmf

# RUN mkdir -p ${TEMPLATES_DIR} && \
#     wget ${EISVOGEL_REPO}/${EISVOGEL_VERSION}/eisvogel.tex -O ${TEMPLATES_DIR}/eisvogel.latex && \
#     # Links for the non-existent
#     ln -s ${TEXMFLOCAL} /texmf && \
#     # Links for the root user
#     ln -s /.pandoc /root/.pandoc && \
#     ln -s ${TEXMFLOCAL} /root/texmf

RUN tlmgr init-usertree && \
    tlmgr install awesomebox fontawesome ly1 inconsolata sourcesanspro sourcecodepro mweights noto roboto && \
    # fixup: download awesome-compat
    # this may not be requitred with debian buster
    # see: https://github.com/Wandmalfarbe/pandoc-latex-template/issues/154#issuecomment-586620431
    wget https://raw.githubusercontent.com/milouse/latex-awesomebox/master/awesomebox-compat.sty \
            -O ${TEXMFLOCAL}/tex/latex/awesomebox/awesomebox-compat.sty

# letter template
ARG LETTER_REPO=https://raw.githubusercontent.com/aaronwolen/pandoc-letter
ARG LETTER_VERSION=master
RUN wget ${LETTER_REPO}/${LETTER_VERSION}/template-letter.tex -O ${TEMPLATES_DIR}/letter.latex

# leaflet template
ARG LEAFLET_REPO=https://gitlab.com/daamien/pandoc-leaflet-template/raw
ARG LEAFLET_VERSION=1.0
RUN wget ${LEAFLET_REPO}/${LEAFLET_VERSION}/leaflet.latex -O ${TEMPLATES_DIR}/leaflet.latex




#
# emojis support for latex
# https://github.com/mreq/xelatex-emoji
#
ARG TEXMF=/usr/share/texmf/tex/latex/
ARG EMOJI_DIR=/tmp/twemoji
RUN git clone --single-branch --depth=1 --branch gh-pages https://github.com/twitter/twemoji.git $EMOJI_DIR && \
    # fetch xelatex-emoji
    mkdir -p ${TEXMF} && \
    cd ${TEXMF} && \
    git clone --single-branch --branch images https://github.com/daamien/xelatex-emoji.git && \
    # convert twemoji SVG files into PDF files
    cp -r $EMOJI_DIR/2/svg xelatex-emoji/images && \
    cd xelatex-emoji/images && \
    ../bin/convert_svgs_to_pdfs ./*.svg && \
    # clean up
    rm -f *.svg && \
    rm -fr ${EMOJI_DIR} && \
    # update texlive
    cd ${TEXMF} && \
    texhash

VOLUME /pandoc
WORKDIR /pandoc

# Compatibility with Pandoc 1.x arguments
# use `--entrypoint=pandoc1.sh` to activate it
ADD pandoc1.sh /usr/local/bin
ENTRYPOINT ["pandoc"]
