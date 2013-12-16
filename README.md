# Obirs-Skin

Obirs skin is a web GUI built uppon the Obirs engine.

Obirs-skin build its indexation from a triple-store database.

## Installation

#### Install Node.js (on Ubuntu)

	$ sudo apt-get install python-software-properties
	$ sudo add-apt-repository ppa:chris-lea/node.js
	$ sudo apt-get update
	$ sudo apt-get install nodejs nodejs-dev npm

### Install Virtuoso

Download and install Virtuoso 7.0 (http://virtuoso.openlinksw.com/)

Once Virtuoso is installed (say in the directory /usr/local/virtuoso-opensource), Open the file
`/usr/local/virtuoso-opensource/var/lib/virtuoso/db/virtuoso.ini` and add "/tmp" to the line `DirsAllowed`

Start virtuoso

### Install Java 7

Obirs's alogrithms are code in obirs.jar and require Java 7.

Be sure $JAVA_HOME is well set (must point to the jdk):

	$ export JAVA_HOME=/usr/lib/jvm/jdk1.7.0

### Install Obirs-Skin

Go to the obirs-skin directory (where the file `package.json` is located) and type:

	$ npm install
	$ npm run-script compile
	$ npm run-script genconfig


## Configuration

Edit the file `config.json` to fill your needs. The configuration file take the following form:

 **port**: (default 4001) the port where the server should listen at
 **endpointURI**: (default "http://localhost:8890/sparql") the sparql endpoint uri where
 **graphURI**: the name of the graphURI (ex: http://kalitmo.org/itcancer)
 **ontologyFilePath**: the ontology file path. (should be located in `data/ontologies`)
 **indexationFilePath**: indexation file path. Where the indexation fil should be built. (often in data/indexations)
 **engine**: (default "mohameth2010") the engine to use. There are currently 3 engines available: 
 	* `mohamteh2010` (from the LGI2P publication)
 	* `groupwise-standalone`: direct groupwise measure (like jackar)
 	* `groupwise-adon`: groupwise measure (pairwise used in groupwise)


### MeSH Ontology

Obirs needs the MeSH Ontology to work. Grab your version and copy the files `desc2013.dtd` and  `desc2013.xml` into the directory `data/ontologies/mesh`.

## Starting Kalitmo

	$ ./obirs

Note that there is no-need to build the indexation before. At launch, Obirs will check if the data/kalitmo-publications.json
exists. if not, the indexation will be buit from the triple store.

Obirs will be accessible at the following address: http://localhost:4001/public/app.html

## Deployement

If you want to deploy obirs on a server, you can use pm2 to detach and monitor the process:

	$ sudo npm install -g pm2
	$ pm2 start obirs

To stop obirs, type:

	$ pm2 stop obirs

After that, if you want to launch obirs the other way (say `./obirs`) it may throw and error meaning that the port is already taken. All you have to do is to kill the pm2 daemon:

	$ pm2 kill
	$ ./obirs

Obirs will be accessible at the following address: http://localhost:4001/public/app.html

## Using Obirs

Go to http://localhost:4001/public/app.html, you should see a graphical interface to make your queries.

### Using Obirs in command line

#### Via Obirs-Skin API

	$ curl -H "Content-type: application/json" -XPOST http://localhost:4001/api/query/ \
	-d '{"concepts":[{"id":"D012725","weight":0.24812030075187969},{"id":"D036703","weight":0.7518796992481203}],"defaultNameSpace":"http://obirs","aggregatorParameter":2}'

#### Via jar

	$ java -jar javalib/obirs.jar -o ~/Documents/Projects/lgi2p/obirs/data/ontologies/mesh/desc2013.xml -i ~/Documents/Projects/lgi2p/obirs/data/indexations/kalitmo-publications.json  -q '{"concepts": [{"id": "D006801", "weight": 0.17},{"id":"D002650", "weight": 0.17},{"id": "D000223", "weight": 0.17},{"id": "D006701", "weight": 0.17},{"id": "D003954", "weight": 0.17},{"id": "D006699", "weight": 0.17}], "defaultNameSpace": "http://obirs", "aggregatorParameter": "2"}'



## License

CeCILL-B FREE SOFTWARE LICENSE AGREEMENT
http://www.cecill.info/licences/Licence_CeCILL-B_V1-en.txt
