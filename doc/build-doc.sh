#!/bin/bash

if [[ $# -ne 2 ]]; then
   printf "$#\n"
   printf "Usage: $0 NAME DOC_REPO_URL\n"
   exit 1
fi

NAME=$1
DOC_REPO=$2

COMMIT_USER="StevenRob1958"
COMMIT_EMAIL="gobrecht1856@gmail.com"

COMMIT=$(git rev-parse --verify HEAD | cut -c1-7)
MAYBE_TAG=$(git describe --exact-match --tags $1 2> /dev/null | sed 's/tags\///')

if [[ -n $MAYBE_TAG ]] ; then
    printf "Found tag: $MAYBE_TAG\n"
    COMMITISH=$MAYBE_TAG
else
    # Prepend with a "g" so it's clear this is a git commit
    COMMITISH="g${COMMIT}"
fi

RELEASE=$COMMITISH
PUBLISH=1

DOC_DIR="doc"
BUILD_DIR="build"
DOC_BUILD_DIR="build/doc"
RELEASE_DIR_NAME="${NAME}_${RELEASE}_documentation"

GRAPHS_PATH=$DOC_BUILD_DIR/graphs
XML_PATH=$DOC_BUILD_DIR/xml
HTML_PATH=$DOC_BUILD_DIR/html

mkdir -p $BUILD_DIR

# Clean DOC_BUILD_DIR before we make it
rm -rf $DOC_BUILD_DIR

mkdir -p $DOC_BUILD_DIR
mkdir -p $DOC_BUILD_DIR/html
mkdir -p $DOC_BUILD_DIR/tag
mkdir -p $GRAPHS_PATH
mkdir -p $XML_PATH
mkdir -p $HTML_PATH

doxygen ${DOC_DIR}/Doxyfile_1

if [[ $? -ne 0 ]]; then
    printf "Error running doxygen\n"
    exit 1
fi

$(cd ${XML_PATH} && xsltproc combine.xslt index.xml > all.xml)

#create the graphs for doxygen

python ${DOC_DIR}/create_groups.py ${BUILD_DIR} ${DOC_BUILD_DIR}

if [[ $? -ne 0 ]]; then
    printf "Error running doxygen\n"
    exit 1
fi

doxygen ${DOC_DIR}/Doxyfile_2

if [[ $? -ne 0 ]]; then
    printf "Error running doxygen\n"
    exit 1
fi


if [[ -n $PUBLISH ]] ; then

    # FIXME: This could just reset the state of the repo if it exists
    # e.g. Check to see if surf-doc exists
    # If not, clone, if it does, do a pull
    cd $BUILD_DIR && git clone ${DOC_REPO} && cd -
    DOC_REPO_DIRNAME=$(basename $DOC_REPO | sed 's/\.git$//')
    DOC_REPO_DIR=${BUILD_DIR}/${DOC_REPO_DIRNAME}

    mkdir -p ${DOC_REPO_DIR}/${RELEASE_DIR_NAME}
    cp -r ${DOC_BUILD_DIR}/html ${DOC_REPO_DIR}/${RELEASE_DIR_NAME}/.
    python ${DOC_DIR}/update_index.py ${NAME} ${RELEASE} ${DOC_REPO_DIR}/index.html

    # Only commit/push if there's actually a tag
    if [[ -n "$MAYBE_TAG" ]] ; then
        cd ${DOC_REPO_DIR}
        git add .
        git commit -m "Automated documentation build for changeset ${COMMIT}."
        git push
        cd -
    fi
fi
