#!/bin/bash

HELP="usage: 
--group={test|generic|mappings|wikidata} [--databus-deploy|--skip-dief-install]

description:
--group={test|generic|mappings|wikidata} : required
	selects download.\$GROUP.properties and extraction.\$GROUP.properties from extractionConfig dir
	Some exceptions are hard coded like 'extraction.generic.en.properties'

[--skip-dief-install] : optional 
	'false' -> each run does a fresh checkout install of the DIEF (DBpedia Information Extraction Framework)
	'true'  -> skipped  

"


##############
# setup paths
##############
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/marvin/"
CONFIGDIR="$ROOT/extractionConfiguration"

# set and create
LOGDIR="$ROOT/logs/$(date +%Y-%m-%d)" && mkdir -p $LOGDIR
DIEFDIR="$ROOT/extraction-framework"

# TODO
EXTRACTIONBASEDIR="$ROOT/wikidumps"
DATAPUSMAVENPLUGINPOMDIR="$ROOT/databus-maven-plugin"
RELEASEDIR="$ROOT/release"
DATAPUSMAVENPLUGINPOMGIT="https://github.com/dbpedia/databus-maven-plugin.git"    

mkdir -p $EXTRACTIONBASEDIR
mkdir -p $RELEASEDIR

#################
#check arguments
#################
GROUP=""
DATABUSDEPLOY=false
SKIPDIEFINSTALL=false

for i in "$@"
do
case $i in
    -g=*|--group=*)
    GROUP="${i#*=}"
    shift
    ;;
    --databus-deploy)
    DATABUSDEPLOY=true
    shift
    ;;
    --skip-dief-install)
    SKIPDIEFINSTALL=true
    shift
    ;;
    -h|--help)
    echo -e $HELP
    exit 1
    shift
    ;;
    *)
    echo "unknown option: $i"
    echo "$HELP"
    exit 1
    ;;
esac
done

if [ "$GROUP" != "generic" ] && [ "$GROUP" != "mappings" ] && [ "$GROUP" != "test" ] && [ "$GROUP" != "wikidata" ] || [ -z "$GROUP" ]
then
    echo "$HELP"
    exit 1
fi


#######################
# include all functions
#######################
source marvin_extraction_functions.sh

#######################
# run
#######################

# PRE-PROCESSING
prepareExtractionFramework;
exit
downloadMetadata &> $LOGDIR/downloadMetadata.log;

# EXTRACT
extractDumps &> $LOGDIR/extracion.log;

# POST-PROCESSING
postProcessing 2> $LOGDIR/postProcessing.log;

# RELEASE 
databusRelease 2> $LOGDIR/databusDeploy.log

# CLEANUP
cleanLogFiles;