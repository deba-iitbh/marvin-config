#!/bin/bash

# check git, curl, maven, java (1.8), lbzip2


prepareExtractionFramework(){
	if [ "$SKIPDIEFINSTALL" = "false" ]
    then
		rm -r $DIEFDIR
		git clone "https://github.com/dbpedia/extraction-framework.git" $DIEFDIR
		cd $DIEFDIR
		# todo add config
		mvn clean install
    else
		echo "skipping DIEF installation"
    fi
}

# clone repositories
gitCheckout() {
    if [ -d $EXTRACTIONFRAMEWORKDIR/.git ]
    then
        cd $EXTRACTIONFRAMEWORKDIR;
        echo -n "extraction-framework "
        git pull;
    else 
        git clone $EXTRACTIONFRAMEWORKGIT
    fi
    if [ -d $DATAPUSMAVENPLUGINPOMDIR/.git ]
    then
        cd $DATAPUSMAVENPLUGINPOMDIR;
        echo -n "databus-maven-plugin "
        git pull;
    else 
        git clone $DATAPUSMAVENPLUGINPOMGIT
    fi
}

# download ontology, mappings, wikidataR2R
downloadMetadata() {
    cd $EXTRACTIONFRAMEWORKDIR/core;
    ../run download-ontology;
    ../run download-mappings;
    cd $EXTRACTIONFRAMEWORKDIR/core/src/main/resources;
    curl https://raw.githubusercontent.com/dbpedia/extraction-framework/master/core/src/main/resources/wikidatar2r.json > wikidatar2r.json;
}

# downlaod and extract data
extractDumps() {
    cd $ROOT && cp $ROOT/config.d/universal.properties.template $EXTRACTIONFRAMEWORKDIR/core/src/main/resources/universal.properties;
    sed -i -e 's,$BASEDIR,'$EXTRACTIONBASEDIR',g' $EXTRACTIONFRAMEWORKDIR/core/src/main/resources/universal.properties;
    sed -i -e 's,$LOGDIR,'$LOGDIR',g' $EXTRACTIONFRAMEWORKDIR/core/src/main/resources/universal.properties;

    
    cd $EXTRACTIONFRAMEWORKDIR/dump;

	# run for all 
	>&2 ../run download $ROOT/config.d/download.$GROUP.properties;
    >&2 ../run extraction $ROOT/config.d/extraction.$GROUP.properties;

    # exception for generic, as English is big and has to be run separately
    if [ "$GROUP" = "generic" ]
    then
       >&2 ../run sparkextraction $ROOT/config.d/extraction.generic.en.properties;
    fi
    
   
}

# post-processing
postProcessing() {

    cd $EXTRACTIONFRAMEWORKDIR/scripts;

    if [ "$GROUP" = "mappings" ]
    then
        echo "mappings postProcessing"
        >&2 ../run ResolveTransitiveLinks $EXTRACTIONBASEDIR redirects redirects_transitive .ttl.bz2 @downloaded;
        >&2 ../run MapObjectUris $EXTRACTIONBASEDIR redirects_transitive .ttl.bz2 mappingbased-objects-uncleaned _redirected .ttl.bz2 @downloaded;
        >&2 ../run TypeConsistencyCheck type.consistency.check.properties;
        
        #TODO databus scripts
        cd $CONFIGDIR;
        source prepareMappingsArtifacts.sh; BASEDIR=$EXTRACTIONBASEDIR; DATABUSMVNPOMDIR=$DATAPUSMAVENPLUGINPOMDIR;
        prepareM;

    elif [ "$GROUP" = "wikidata" ]
    then
        echo "wikidata postProcessing"
        >&2 ../run ResolveTransitiveLinks $BASEDIR redirects transitive-redirects .ttl.bz2 wikidata
        >&2 ../run MapObjectUris $BASEDIR transitive-redirects .ttl.bz2 mappingbased-objects-uncleaned,raw -redirected .ttl.bz2 wikidata
        >&2 ../run TypeConsistencyCheck type.consistency.check.properties;

        # cd $ROOT/config.d;
        # source prepareMappingsArtifacts.sh; BASEDIR=$EXTRACTIONBASEDIR; DATABUSMVNPOMDIR=$DATAPUSMAVENPLUGINPOMDIR;
        # prepareW;

    elif [ "$GROUP" = "generic" ] 
    then
        echo "generic postProcessing"
        >&2 ../run ResolveTransitiveLinks $BASEDIR redirects redirects_transitive .ttl.bz2 @downloaded;
        >&2 ../run MapObjectUris $BASEDIR redirects_transitive .ttl.bz2 disambiguations,infobox-properties,page-links,persondata,topical-concepts _redirected .ttl.bz2 @downloaded;

        # cd $ROOT/config.d;
        # source prepareMappingsArtifacts.sh; BASEDIR=$EXTRACTIONBASEDIR; DATABUSMVNPOMDIR=$DATAPUSMAVENPLUGINPOMDIR;
        # prepareG;

    elif [ "$GROUP" = "abstract" ]
    then
        echo "abstract postProcessing"

    elif [ "$GROUP" = "test" ]
    then 
        echo "test postProcessing"
        >&2 ../run ResolveTransitiveLinks $EXTRACTIONBASEDIR redirects redirects_transitive .ttl.bz2 @downloaded;
        >&2 ../run MapObjectUris $EXTRACTIONBASEDIR redirects_transitive .ttl.bz2 mappingbased-objects-uncleaned _redirected .ttl.bz2 @downloaded;
        >&2 ../run TypeConsistencyCheckManual mappingbased-objects instance-types ro;

        cd $ROOT/config.d;
        source prepareMappingsArtifacts.sh; BASEDIR=$EXTRACTIONBASEDIR; DATABUSMVNPOMDIR=$DATAPUSMAVENPLUGINPOMDIR/databus-maven-plugin/dbpedia/mappings;
        prepareM;
    fi
}

# release
databusRelease() {

    if [ "$DATABUSDEPLOY" = "true" ]
    then
        cd $DATAPUSMAVENPLUGINPOMDIR;
        mvn versions:set -DnewVersion=$(ls * | grep '^[0-9]\{4\}.[0-9]\{2\}.[0-9]\{2\}$' | sort -u  | tail -1);

        RELEASEPUBLISHER="https://vehnem.github.io/webid.ttl#this";
        RELEASEPACKAGEDIR="/data/extraction/release/\${project.groupId}/\${project.artifactId}";
        RELEASEDOWNLOADURL="http://dbpedia-generic.tib.eu/release/\${project.groupId}/\${project.artifactId}/\${project.version}/";
        RELEASELABELPREFIX="(pre-release)";
        RELEASECOMMENTPREFIX="(MARVIN is the DBpedia bot, that runs the DBpedia Information Extraction Framework (DIEF) and releases the data as is, i.e. unparsed, unsorted, not redirected for debugging the software. After its releases, data is cleaned and persisted under the dbpedia account.)";

        >&2 mvn clean deploy -Ddatabus.publisher="$RELEASEPUBLISHER" -Ddatabus.packageDirectory="$RELEASEPACKAGEDIR" -Ddatabus.downloadUrlPath="$RELEASEDOWNLOADURL" -Ddatabus.labelPrefix="$RELEASELABELPREFIX" -Ddatabus.commentPrefix="$RELEASECOMMENTPREFIX";
    fi
}

# clean up: compress log files
cleanLogFiles() {
    for f in $(find $LOGDIR -type f ); do lbzip2 $f; done;
}
