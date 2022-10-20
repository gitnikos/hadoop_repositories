#!/bin/bash

if [ "$1" == "" ]; then
	echo "Error: You did not specify the path of the directory to process"
	echo "Syntax: $0 /path/to/project/lib/containing/jar/files"
	exit 1;
fi

cd "$1"

for file in `find . | grep ".jar" | sed "s/^\.\///g"`; do 

VERSION=`unzip -p - $file META-INF/maven/*/*/pom.properties 2>/dev/null | grep "^version" | cut -d '=' -f 2 | sed -e 's/[[:space:]]*$//'`
ART=`unzip -p - $file META-INF/maven/*/*/pom.properties 2>/dev/null | grep "^artifactId" | cut -d '=' -f 2 | sed -e 's/[[:space:]]*$//'`
GROUP=`unzip -p - $file META-INF/maven/*/*/pom.properties 2>/dev/null | grep "^groupId" | cut -d '=' -f 2 | sed -e 's/[[:space:]]*$//'`

echo "//  $file -->" >> build.gradle

if [ "$VERSION" != "" ]; then
	echo "$file found dep info in jar"
	echo "implementation \"$GROUP:$ART:$VERSION\"" >> build.gradle
	echo "" >> build.gradle
else
	SHA1=`sha1sum $file`
	#LOOKUPINFO=`lookup-jar.py $file $SHA1`

	# call python script to lookup jar by SHA1 checksum on search.maven.org
	LOOKUPINFO=$(python - $file $SHA1 << END
import json
import urllib2
import sys
import os
jar = sys.argv[1]
sha = sys.argv[2]
searchurl = 'http://search.maven.org/solrsearch/select?q=1:%22'+sha+'%22&rows=20&wt=json'
page = urllib2.urlopen(searchurl)
data = json.loads("".join(page.readlines()))
if data["response"] and data["response"]["numFound"] == 1:
	print "//  Found info on search.maven.org for "+jar+" -->\r\n"
	jarinfo = data["response"]["docs"][0]
	print 'implementation "'+jarinfo["g"]+':'+jarinfo["a"]+':'+jarinfo["v"]+'"\r\n'
END
)
	
	if [ "$LOOKUPINFO" != "" ]; then
		echo "// $file found dep info at search.maven.org"
		echo $LOOKUPINFO >> build.gradle
	else
		echo $file >> missing.gradle
	fi
fi

done
	